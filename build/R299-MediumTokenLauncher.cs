// R299 hosted-only test helper. Creates child processes using the same account's
// linked UAC-limited token and verifies the actual child token is medium integrity.
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public sealed class R299MediumProcess : IDisposable
{
    private IntPtr _processHandle;
    public int Id { get; private set; }

    internal R299MediumProcess(IntPtr processHandle, uint processId)
    {
        _processHandle = processHandle;
        Id = checked((int)processId);
    }

    private void EnsureOpen()
    {
        if (_processHandle == IntPtr.Zero)
            throw new ObjectDisposedException("R299MediumProcess");
    }

    public bool HasExited
    {
        get
        {
            EnsureOpen();
            uint result = WaitForSingleObject(_processHandle, 0);
            if (result == 0) return true;
            if (result == 258) return false;
            throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_WAIT_PROCESS_FAILED");
        }
    }

    public bool WaitForExit(int milliseconds)
    {
        EnsureOpen();
        if (milliseconds < 0) throw new ArgumentOutOfRangeException("milliseconds");
        uint result = WaitForSingleObject(_processHandle, unchecked((uint)milliseconds));
        if (result == 0) return true;
        if (result == 258) return false;
        throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_WAIT_PROCESS_FAILED");
    }

    public int ExitCode
    {
        get
        {
            EnsureOpen();
            uint code;
            if (!GetExitCodeProcess(_processHandle, out code))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_GET_PROCESS_EXIT_CODE_FAILED");
            if (code == 259) throw new InvalidOperationException("R299_PROCESS_STILL_ACTIVE");
            return unchecked((int)code);
        }
    }

    public void Kill()
    {
        EnsureOpen();
        if (HasExited) return;
        if (!TerminateProcess(_processHandle, 0xC000013A))
        {
            int error = Marshal.GetLastWin32Error();
            if (HasExited) return;
            throw new Win32Exception(error, "R299_TERMINATE_OWNED_CHILD_FAILED");
        }
    }

    public void Dispose()
    {
        if (_processHandle != IntPtr.Zero)
        {
            CloseHandle(_processHandle);
            _processHandle = IntPtr.Zero;
        }
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(IntPtr process, uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);
}

public static class R299MediumTokenLauncher
{
    private const uint TOKEN_ASSIGN_PRIMARY = 0x0001;
    private const uint TOKEN_DUPLICATE = 0x0002;
    private const uint TOKEN_QUERY = 0x0008;
    private const uint CREATE_UNICODE_ENVIRONMENT = 0x00000400;
    private const uint CREATE_NO_WINDOW = 0x08000000;
    private const int TokenUser = 1;
    private const int TokenType = 8;
    private const int TokenImpersonationLevel = 9;
    private const int TokenElevationType = 18;
    private const int TokenLinkedToken = 19;
    private const int TokenElevation = 20;
    private const int TokenIntegrityLevel = 25;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct STARTUPINFO
    {
        public uint cb;
        public IntPtr lpReserved;
        public IntPtr lpDesktop;
        public IntPtr lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public ushort wShowWindow;
        public ushort cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PROCESS_INFORMATION
    {
        public IntPtr hProcess;
        public IntPtr hThread;
        public uint dwProcessId;
        public uint dwThreadId;
    }

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint desiredAccess, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(IntPtr token, int informationClass,
        IntPtr information, int informationLength, out int returnLength);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool DuplicateTokenEx(IntPtr existingToken, uint desiredAccess,
        IntPtr tokenAttributes, int impersonationLevel, int tokenType, out IntPtr newToken);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern bool CreateProcessWithTokenW(IntPtr token, uint logonFlags,
        string applicationName, StringBuilder commandLine, uint creationFlags,
        IntPtr environment, string currentDirectory, ref STARTUPINFO startupInfo,
        out PROCESS_INFORMATION processInformation);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern IntPtr GetSidSubAuthorityCount(IntPtr sid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern IntPtr GetSidSubAuthority(IntPtr sid, uint subAuthority);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "ConvertSidToStringSidW")]
    private static extern bool ConvertSidToStringSid(IntPtr sid, out IntPtr stringSid);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LocalFree(IntPtr memory);

    private static IntPtr QueryTokenBuffer(IntPtr token, int informationClass)
    {
        int required = 0;
        GetTokenInformation(token, informationClass, IntPtr.Zero, 0, out required);
        int firstError = Marshal.GetLastWin32Error();
        if (required <= 0 || firstError != 122)
            throw new Win32Exception(firstError, "R299_TOKEN_INFORMATION_SIZE_QUERY_FAILED_CLASS_" + informationClass);

        IntPtr buffer = Marshal.AllocHGlobal(required);
        if (!GetTokenInformation(token, informationClass, buffer, required, out required))
        {
            int error = Marshal.GetLastWin32Error();
            Marshal.FreeHGlobal(buffer);
            throw new Win32Exception(error, "R299_TOKEN_INFORMATION_QUERY_FAILED_CLASS_" + informationClass);
        }
        return buffer;
    }

    private static int ReadTokenInt(IntPtr token, int informationClass)
    {
        IntPtr buffer = QueryTokenBuffer(token, informationClass);
        try { return Marshal.ReadInt32(buffer); }
        finally { Marshal.FreeHGlobal(buffer); }
    }

    private static string ReadTokenUserSid(IntPtr token)
    {
        IntPtr buffer = QueryTokenBuffer(token, TokenUser);
        try
        {
            IntPtr sid = Marshal.ReadIntPtr(buffer);
            if (sid == IntPtr.Zero) throw new InvalidOperationException("R299_TOKEN_USER_SID_MISSING");
            IntPtr text;
            if (!ConvertSidToStringSid(sid, out text))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_TOKEN_SID_CONVERSION_FAILED");
            try { return Marshal.PtrToStringUni(text); }
            finally { LocalFree(text); }
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }

    private static int ReadIntegrityRid(IntPtr token)
    {
        IntPtr buffer = QueryTokenBuffer(token, TokenIntegrityLevel);
        try
        {
            IntPtr sid = Marshal.ReadIntPtr(buffer);
            if (sid == IntPtr.Zero) throw new InvalidOperationException("R299_TOKEN_INTEGRITY_SID_MISSING");
            IntPtr countPointer = GetSidSubAuthorityCount(sid);
            if (countPointer == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_TOKEN_INTEGRITY_COUNT_FAILED");
            byte count = Marshal.ReadByte(countPointer);
            if (count == 0) throw new InvalidOperationException("R299_TOKEN_INTEGRITY_COUNT_EMPTY");
            IntPtr ridPointer = GetSidSubAuthority(sid, (uint)(count - 1));
            if (ridPointer == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_TOKEN_INTEGRITY_RID_FAILED");
            return Marshal.ReadInt32(ridPointer);
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }

    private static void ValidateMediumToken(IntPtr token, string expectedUserSid, string label, bool requirePrimary)
    {
        int elevationType = ReadTokenInt(token, TokenElevationType);
        int elevated = ReadTokenInt(token, TokenElevation);
        int tokenType = ReadTokenInt(token, TokenType);
        int impersonationLevel = tokenType == 2 ? ReadTokenInt(token, TokenImpersonationLevel) : 0;
        int integrityRid = ReadIntegrityRid(token);
        string userSid = ReadTokenUserSid(token);
        bool usableTokenType = tokenType == 1 || (!requirePrimary && tokenType == 2 && impersonationLevel >= 2);
        bool sameUser = String.Equals(userSid, expectedUserSid, StringComparison.OrdinalIgnoreCase);
        if (elevationType != 3 || elevated != 0 || !usableTokenType || integrityRid != 0x2000 || !sameUser)
        {
            throw new InvalidOperationException(
                "R299_" + label + "_TOKEN_NOT_MEDIUM_LIMITED_SAME_USER" +
                "_type=" + elevationType + "_elevated=" + elevated +
                "_tokenType=" + tokenType + "_impersonationLevel=" + impersonationLevel +
                "_integrity=0x" + integrityRid.ToString("X") + "_sameUser=" + sameUser);
        }
    }

    private static string QuoteArgument(string value)
    {
        StringBuilder result = new StringBuilder();
        result.Append('"');
        int backslashes = 0;
        foreach (char c in value)
        {
            if (c == '\\') { backslashes++; continue; }
            if (c == '"')
            {
                result.Append('\\', checked(backslashes * 2 + 1));
                result.Append('"');
                backslashes = 0;
                continue;
            }
            result.Append('\\', backslashes);
            backslashes = 0;
            result.Append(c);
        }
        result.Append('\\', checked(backslashes * 2));
        result.Append('"');
        return result.ToString();
    }

    public static R299MediumProcess Start(string application, string[] arguments,
        string workingDirectory, string environmentBlock)
    {
        if (String.IsNullOrWhiteSpace(application) || !System.IO.Path.IsPathRooted(application))
            throw new ArgumentException("R299_APPLICATION_MUST_BE_ABSOLUTE", "application");
        if (String.IsNullOrWhiteSpace(workingDirectory) || !System.IO.Path.IsPathRooted(workingDirectory))
            throw new ArgumentException("R299_WORKING_DIRECTORY_MUST_BE_ABSOLUTE", "workingDirectory");
        if (String.IsNullOrEmpty(environmentBlock) || environmentBlock.Length < 2 ||
            environmentBlock[environmentBlock.Length - 1] != '\0' ||
            environmentBlock[environmentBlock.Length - 2] != '\0')
            throw new ArgumentException("R299_ENVIRONMENT_BLOCK_MUST_END_WITH_DOUBLE_NUL", "environmentBlock");

        IntPtr parentToken = IntPtr.Zero;
        IntPtr linkedBuffer = IntPtr.Zero;
        IntPtr linkedToken = IntPtr.Zero;
        IntPtr primaryToken = IntPtr.Zero;
        IntPtr environment = IntPtr.Zero;
        PROCESS_INFORMATION processInfo = new PROCESS_INFORMATION();
        try
        {
            if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, out parentToken))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_OPEN_PARENT_TOKEN_FAILED");
            if (ReadTokenInt(parentToken, TokenElevationType) != 2 ||
                ReadTokenInt(parentToken, TokenElevation) != 1)
                throw new InvalidOperationException("R299_PARENT_MUST_HAVE_FULL_UAC_ELEVATION_TOKEN");

            string parentSid = ReadTokenUserSid(parentToken);
            linkedBuffer = QueryTokenBuffer(parentToken, TokenLinkedToken);
            linkedToken = Marshal.ReadIntPtr(linkedBuffer);
            if (linkedToken == IntPtr.Zero) throw new InvalidOperationException("R299_LINKED_LIMITED_TOKEN_MISSING");
            ValidateMediumToken(linkedToken, parentSid, "LINKED", false);

            const uint requiredTokenAccess = TOKEN_QUERY | TOKEN_DUPLICATE | TOKEN_ASSIGN_PRIMARY;
            if (!DuplicateTokenEx(linkedToken, requiredTokenAccess, IntPtr.Zero,
                2, 1, out primaryToken))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_DUPLICATE_LINKED_PRIMARY_TOKEN_FAILED");
            ValidateMediumToken(primaryToken, parentSid, "DUPLICATED", true);

            string command = QuoteArgument(application);
            if (arguments != null)
            {
                foreach (string argument in arguments)
                {
                    command += " " + QuoteArgument(argument ?? String.Empty);
                }
            }
            if (command.Length > 1024)
                throw new ArgumentException("R299_MEDIUM_PROCESS_COMMAND_LINE_EXCEEDS_WIN32_LIMIT");

            environment = Marshal.StringToHGlobalUni(environmentBlock);
            STARTUPINFO startup = new STARTUPINFO();
            startup.cb = (uint)Marshal.SizeOf(typeof(STARTUPINFO));

            if (!CreateProcessWithTokenW(primaryToken, 1, application,
                new StringBuilder(command), CREATE_UNICODE_ENVIRONMENT | CREATE_NO_WINDOW,
                environment, workingDirectory, ref startup, out processInfo))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_CREATE_PROCESS_WITH_LINKED_MEDIUM_TOKEN_FAILED");

            IntPtr childToken = IntPtr.Zero;
            try
            {
                if (!OpenProcessToken(processInfo.hProcess, TOKEN_QUERY, out childToken))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_OPEN_CREATED_CHILD_TOKEN_FAILED");
                ValidateMediumToken(childToken, parentSid, "CREATED_CHILD", true);
            }
            finally
            {
                if (childToken != IntPtr.Zero) CloseHandle(childToken);
            }

            R299MediumProcess result = new R299MediumProcess(processInfo.hProcess, processInfo.dwProcessId);
            processInfo.hProcess = IntPtr.Zero;
            return result;
        }
        catch
        {
            if (processInfo.hProcess != IntPtr.Zero)
            {
                TerminateProcess(processInfo.hProcess, 0xC000013A);
                WaitForSingleObject(processInfo.hProcess, 12000);
            }
            throw;
        }
        finally
        {
            if (processInfo.hThread != IntPtr.Zero) CloseHandle(processInfo.hThread);
            if (processInfo.hProcess != IntPtr.Zero) CloseHandle(processInfo.hProcess);
            if (environment != IntPtr.Zero) Marshal.FreeHGlobal(environment);
            if (primaryToken != IntPtr.Zero) CloseHandle(primaryToken);
            if (linkedToken != IntPtr.Zero) CloseHandle(linkedToken);
            if (linkedBuffer != IntPtr.Zero) Marshal.FreeHGlobal(linkedBuffer);
            if (parentToken != IntPtr.Zero) CloseHandle(parentToken);
        }
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(IntPtr process, uint exitCode);
}
