using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace TaskbarMonitorSensorBroker
{
    // R408: a directly invoked (possibly elevated) Broker must enforce its own
    // output authority; Supervisor argv validation alone is not a security boundary.
    internal sealed class BrokerOutputBoundary : IDisposable
    {
        const uint ReadAttributes=0x80,ShareReadWrite=3,OpenExisting=3;
        const uint BackupSemantics=0x02000000,OpenReparsePoint=0x00200000;
        const uint DirectoryAttribute=0x10,ReparseAttribute=0x400;
        const uint InvalidAttributes=0xFFFFFFFF;
        readonly List<SafeFileHandle> heldDirectories=new List<SafeFileHandle>();
        readonly List<string> pinnedDirectoryNames=new List<string>();

        [StructLayout(LayoutKind.Sequential)]
        struct FileAttributeTagInfo { public uint Attributes; public uint ReparseTag; }

        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true,EntryPoint="CreateFileW")]
        static extern SafeFileHandle CreateFile(string path,uint access,uint share,IntPtr security,uint disposition,uint flags,IntPtr template);
        [DllImport("kernel32.dll",SetLastError=true)]
        static extern bool GetFileInformationByHandleEx(SafeFileHandle file,int infoClass,out FileAttributeTagInfo info,uint size);
        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true,EntryPoint="GetFinalPathNameByHandleW")]
        static extern uint GetFinalPathNameByHandle(SafeFileHandle file,System.Text.StringBuilder buffer,uint length,uint flags);
        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true,EntryPoint="GetLongPathNameW")]
        static extern uint GetLongPathName(string path,System.Text.StringBuilder buffer,uint length);
        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true,EntryPoint="GetFileAttributesW")]
        static extern uint GetFileAttributes(string path);

        static string CanonicalExisting(string path)
        {
            string full=Path.GetFullPath(path);
            if(full.StartsWith(@"\\",StringComparison.Ordinal))
                throw new InvalidDataException("Broker rejects network paths.");
            System.Text.StringBuilder b=new System.Text.StringBuilder(4096);
            uint n=GetLongPathName(full,b,(uint)b.Capacity);
            if(n==0 || n>=b.Capacity)
                throw new IOException("Broker cannot canonicalize a local directory: "+Marshal.GetLastWin32Error());
            return Path.GetFullPath(b.ToString());
        }

        static void CheckAttributes(string path,bool optionalFile)
        {
            uint attrs=GetFileAttributes(path);
            if(attrs==InvalidAttributes)
            {
                int error=Marshal.GetLastWin32Error();
                if(optionalFile && error==2) return; // absent leaf only, parent must exist
                throw new IOException("Broker output path cannot be checked: "+error);
            }
            if((attrs&ReparseAttribute)!=0 ||
               ((attrs&DirectoryAttribute)!=0)==optionalFile)
                throw new InvalidDataException("Broker output path has unexpected reparse point or object type.");
        }

        static string ExpectedLeaf(string mode)
        {
            switch(mode)
            {
                case "--run-cpu":return "cpu_temp_broker.json";
                case "--run-gpu":return "gpu_temp_broker.json";
                case "--once-storage":return "storage_temp_broker.json";
                default:throw new InvalidDataException("Broker mode is not allowlisted.");
            }
        }

        internal static string Validate(string mode,string output,string profile,string localAppData)
        {
            string leaf=ExpectedLeaf(mode);
            if(String.IsNullOrWhiteSpace(output)||String.IsNullOrWhiteSpace(profile)||
               String.IsNullOrWhiteSpace(localAppData)||output.Length>2048||
               output.IndexOf('"')>=0||output.IndexOf('\r')>=0||output.IndexOf('\n')>=0)
                throw new InvalidDataException("Broker output path is not a bounded Windows path.");
            string ownerProfile=Path.GetFullPath(profile).TrimEnd(Path.DirectorySeparatorChar);
            string local=Path.GetFullPath(localAppData).TrimEnd(Path.DirectorySeparatorChar);
            if(ownerProfile.StartsWith(@"\\",StringComparison.Ordinal)||
               local.StartsWith(@"\\",StringComparison.Ordinal)||
               String.Equals(ownerProfile,Path.GetPathRoot(ownerProfile),StringComparison.OrdinalIgnoreCase)||
               !String.Equals(local,Path.Combine(ownerProfile,"AppData","Local"),StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("Broker LocalAppData is not owned by this profile.");
            string parent=Path.Combine(local,"TaskbarMonitorEnhanced");
            string expected=Path.Combine(parent,leaf);
            if(!String.Equals(output,expected,StringComparison.OrdinalIgnoreCase)||
               !String.Equals(Path.GetFullPath(output),expected,StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("Broker output does not match the fixed mode-specific owner leaf.");
            if(!Directory.Exists(parent))throw new InvalidDataException("Broker owner directory is missing.");
            // Every component must be a normal directory, not a junction/volume mount.
            string cursor=parent;
            for(int i=0;i<64;i++)
            {
                CheckAttributes(cursor,false);
                string next=Path.GetDirectoryName(cursor);
                if(String.IsNullOrEmpty(next)||String.Equals(next,cursor,StringComparison.OrdinalIgnoreCase))break;
                cursor=next;
                if(i==63)throw new InvalidDataException("Broker owner path depth exceeds bound.");
            }
            CheckAttributes(expected,true);
            return expected;
        }

        void PinDirectory(string path)
        {
            string expected=CanonicalExisting(path);
            SafeFileHandle handle=CreateFile(expected,ReadAttributes,ShareReadWrite,IntPtr.Zero,
                OpenExisting,BackupSemantics|OpenReparsePoint,IntPtr.Zero);
            if(handle==null||handle.IsInvalid)
            {
                int error=Marshal.GetLastWin32Error();
                if(handle!=null)handle.Dispose();
                throw new IOException("Broker cannot pin owner directory: "+error);
            }
            try
            {
                FileAttributeTagInfo info;
                if(!GetFileInformationByHandleEx(handle,9,out info,
                    (uint)Marshal.SizeOf(typeof(FileAttributeTagInfo)))||
                   (info.Attributes&DirectoryAttribute)==0||
                   (info.Attributes&ReparseAttribute)!=0)
                    throw new InvalidDataException("Broker owner directory changed or became a reparse point.");
                System.Text.StringBuilder b=new System.Text.StringBuilder(4096);
                uint n=GetFinalPathNameByHandle(handle,b,(uint)b.Capacity,0);
                if(n==0||n>=b.Capacity)throw new IOException("Broker cannot resolve pinned owner handle.");
                string final=b.ToString();
                if(final.StartsWith(@"\\?\UNC\",StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("Broker pinned a network directory.");
                if(final.StartsWith(@"\\?\",StringComparison.Ordinal))final=final.Substring(4);
                if(!String.Equals(CanonicalExisting(final),expected,StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("Broker pinned owner path identity changed.");
                heldDirectories.Add(handle);
                pinnedDirectoryNames.Add(expected);
            }
            catch{handle.Dispose();throw;}
        }

        internal static BrokerOutputBoundary Acquire(string mode,string output,string profile,string localAppData)
        {
            string allowed=Validate(mode,output,profile,localAppData);
            BrokerOutputBoundary lease=new BrokerOutputBoundary();
            try
            {
                Stack<string> parents=new Stack<string>();
                string cursor=Path.GetDirectoryName(allowed);
                for(int i=0;i<64;i++)
                {
                    string parent=Path.GetDirectoryName(cursor);
                    if(String.IsNullOrEmpty(parent)||String.Equals(parent,cursor,StringComparison.OrdinalIgnoreCase))break;
                    parents.Push(cursor);
                    cursor=parent;
                    if(i==63)throw new InvalidDataException("Broker native path depth exceeds bound.");
                }
                while(parents.Count!=0)lease.PinDirectory(parents.Pop());
                Validate(mode,output,profile,localAppData);
                return lease;
            }
            catch{lease.Dispose();throw;}
        }

        internal static string CurrentValidatedOutput(string mode,string path)
        {
            return Validate(mode,path,
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData));
        }

        internal static BrokerOutputBoundary PinCurrent(string mode,string path)
        {
            return Acquire(mode,path,
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData));
        }

        internal void RevalidateLeaf(string path)
        {
            // A directory handle alone is not proof that the name cannot be
            // rebound: native directory rename semantics vary by filesystem.
            // Compare the live handle identity with the accepted name at every
            // write/replace attempt, then reject a reparse output leaf.
            for(int i=0;i<heldDirectories.Count;i++)
            {
                SafeFileHandle h=heldDirectories[i];
                System.Text.StringBuilder b=new System.Text.StringBuilder(4096);
                uint n=GetFinalPathNameByHandle(h,b,(uint)b.Capacity,0);
                if(n==0||n>=b.Capacity)
                    throw new IOException("Broker owner directory identity disappeared during write.");
                string actual=b.ToString();
                if(actual.StartsWith(@"\\?\UNC\",StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("Broker owner directory became a network path.");
                if(actual.StartsWith(@"\\?\",StringComparison.Ordinal))actual=actual.Substring(4);
                if(!String.Equals(CanonicalExisting(actual),pinnedDirectoryNames[i],StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("Broker owner directory renamed during write.");
                CheckAttributes(pinnedDirectoryNames[i],false);
            }
            CheckAttributes(path,true);
        }

        public void Dispose()
        {
            for(int i=heldDirectories.Count-1;i>=0;i--)heldDirectories[i].Dispose();
            heldDirectories.Clear();
            pinnedDirectoryNames.Clear();
        }
    }
}
