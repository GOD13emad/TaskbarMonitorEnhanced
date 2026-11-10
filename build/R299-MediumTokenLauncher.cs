// R299 hosted-only test helper. Uses a verified same-user Medium token when UAC
// is enabled, or preserves the same-user High administrator token only when UAC
// is disabled (the product's explicitly supported compatibility path).
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32;

public sealed class R299HostedProcess : IDisposable
{
    private IntPtr _processHandle;
    public int Id { get; private set; }
    public string TokenSource { get; private set; }
    public string CreationMethod { get; private set; }
    public int TokenElevationType { get; private set; }
    public int TokenIntegrityRid { get; private set; }
    public bool AdministratorsGroupEnabled { get; private set; }
    public bool UacEnabled { get; private set; }
    public bool ConsoleAllowed { get; private set; }

    internal R299HostedProcess(IntPtr processHandle, uint processId, string tokenSource,
        string creationMethod, int tokenElevationType, int tokenIntegrityRid,
        bool administratorsGroupEnabled, bool uacEnabled, bool consoleAllowed)
    {
        _processHandle = processHandle;
        Id = checked((int)processId);
        TokenSource = tokenSource;
        CreationMethod = creationMethod;
        TokenElevationType = tokenElevationType;
        TokenIntegrityRid = tokenIntegrityRid;
        AdministratorsGroupEnabled = administratorsGroupEnabled;
        UacEnabled = uacEnabled;
        ConsoleAllowed = consoleAllowed;
    }

    private void EnsureOpen()
    {
        if (_processHandle == IntPtr.Zero)
            throw new ObjectDisposedException("R299HostedProcess");
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

public static class R299HostedTokenLauncher
{
    private const uint TOKEN_ASSIGN_PRIMARY = 0x0001;
    private const uint TOKEN_DUPLICATE = 0x0002;
    private const uint TOKEN_QUERY = 0x0008;
    private const uint TOKEN_ADJUST_DEFAULT = 0x0080;
    private const uint CREATE_UNICODE_ENVIRONMENT = 0x00000400;
    private const uint CREATE_NO_WINDOW = 0x08000000;
    private const uint DISABLE_MAX_PRIVILEGE = 0x00000001;
    private const uint SE_GROUP_INTEGRITY = 0x00000020;
    private const int TokenUser = 1;
    private const int TokenType = 8;
    private const int TokenImpersonationLevel = 9;
    private const int TokenElevationType = 18;
    private const int TokenLinkedToken = 19;
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
    private struct SID_AND_ATTRIBUTES
    {
        public IntPtr Sid;
        public uint Attributes;
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
    private static extern bool CreateRestrictedToken(IntPtr existingToken, uint flags,
        uint disableSidCount, ref SID_AND_ATTRIBUTES sidsToDisable,
        uint deletePrivilegeCount, IntPtr privilegesToDelete,
        uint restrictedSidCount, IntPtr sidsToRestrict, out IntPtr newToken);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SetTokenInformation(IntPtr token, int informationClass,
        IntPtr information, int informationLength);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "ConvertStringSidToSidW")]
    private static extern bool ConvertStringSidToSid(string stringSid, out IntPtr sid);

    [DllImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CheckTokenMembership(IntPtr token, IntPtr sid,
        [MarshalAs(UnmanagedType.Bool)] out bool isMember);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool DuplicateTokenEx(IntPtr existingToken, uint desiredAccess,
        IntPtr tokenAttributes, int impersonationLevel, int tokenType, out IntPtr newToken);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern bool CreateProcessW(string applicationName, StringBuilder commandLine,
        IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles, uint creationFlags,
        IntPtr environment, string currentDirectory, ref STARTUPINFO startupInfo,
        out PROCESS_INFORMATION processInformation);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern bool CreateProcessAsUserW(IntPtr token, string applicationName,
        StringBuilder commandLine, IntPtr processAttributes, IntPtr threadAttributes,
        bool inheritHandles, uint creationFlags, IntPtr environment, string currentDirectory,
        ref STARTUPINFO startupInfo, out PROCESS_INFORMATION processInformation);

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
        bool sizeQuerySucceeded = GetTokenInformation(token, informationClass, IntPtr.Zero, 0, out required);
        int firstError = Marshal.GetLastWin32Error();
        if (required <= 0 || (!sizeQuerySucceeded && firstError != 122))
            throw new Win32Exception(firstError,
                "R299_TOKEN_INFORMATION_SIZE_QUERY_FAILED_CLASS_" + informationClass +
                "_required=" + required + "_sizeQuerySucceeded=" + sizeQuerySucceeded);

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

    private static bool IsEnabledMember(IntPtr token, string sidText)
    {
        IntPtr sid = IntPtr.Zero;
        IntPtr membershipToken = IntPtr.Zero;
        try
        {
            if (!ConvertStringSidToSid(sidText, out sid))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_CONVERT_MEMBERSHIP_SID_FAILED");
            if (!DuplicateTokenEx(token, TOKEN_QUERY, IntPtr.Zero, 1, 2, out membershipToken))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_DUPLICATE_MEMBERSHIP_IMPERSONATION_TOKEN_FAILED");
            bool isMember;
            if (!CheckTokenMembership(membershipToken, sid, out isMember))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_CHECK_TOKEN_MEMBERSHIP_FAILED");
            return isMember;
        }
        finally
        {
            if (membershipToken != IntPtr.Zero) CloseHandle(membershipToken);
            if (sid != IntPtr.Zero) LocalFree(sid);
        }
    }

    private static IntPtr CreateRestrictedMediumToken(IntPtr parentToken)
    {
        IntPtr adminSid = IntPtr.Zero;
        IntPtr mediumSid = IntPtr.Zero;
        IntPtr labelBuffer = IntPtr.Zero;
        IntPtr restrictedToken = IntPtr.Zero;
        try
        {
            if (!ConvertStringSidToSid("S-1-5-32-544", out adminSid))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_CONVERT_ADMIN_SID_FAILED");
            SID_AND_ATTRIBUTES disableAdmin = new SID_AND_ATTRIBUTES();
            disableAdmin.Sid = adminSid;
            disableAdmin.Attributes = 0;

            if (!CreateRestrictedToken(parentToken, DISABLE_MAX_PRIVILEGE,
                1, ref disableAdmin, 0, IntPtr.Zero, 0, IntPtr.Zero, out restrictedToken))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_CREATE_RESTRICTED_MEDIUM_TOKEN_FAILED");

            if (!ConvertStringSidToSid("S-1-16-8192", out mediumSid))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_CONVERT_MEDIUM_INTEGRITY_SID_FAILED");
            SID_AND_ATTRIBUTES label = new SID_AND_ATTRIBUTES();
            label.Sid = mediumSid;
            label.Attributes = SE_GROUP_INTEGRITY;
            int labelSize = Marshal.SizeOf(typeof(SID_AND_ATTRIBUTES));
            labelBuffer = Marshal.AllocHGlobal(labelSize);
            Marshal.StructureToPtr(label, labelBuffer, false);
            if (!SetTokenInformation(restrictedToken, TokenIntegrityLevel, labelBuffer, labelSize))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_SET_RESTRICTED_TOKEN_MEDIUM_INTEGRITY_FAILED");

            if (ReadIntegrityRid(restrictedToken) != 0x2000 ||
                IsEnabledMember(restrictedToken, "S-1-5-32-544"))
                throw new InvalidOperationException("R299_RESTRICTED_TOKEN_NOT_MEDIUM_OR_ADMIN_GROUP_STILL_ENABLED");

            IntPtr result = restrictedToken;
            restrictedToken = IntPtr.Zero;
            return result;
        }
        finally
        {
            if (labelBuffer != IntPtr.Zero) Marshal.FreeHGlobal(labelBuffer);
            if (mediumSid != IntPtr.Zero) LocalFree(mediumSid);
            if (adminSid != IntPtr.Zero) LocalFree(adminSid);
            if (restrictedToken != IntPtr.Zero) CloseHandle(restrictedToken);
        }
    }

    private static bool IsUacEnabled()
    {
        try
        {
            using (RegistryKey hive = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64))
            using (RegistryKey key = hive.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", false))
            {
                object value = key == null ? null : key.GetValue("EnableLUA");
                return value == null || Convert.ToInt32(value) != 0;
            }
        }
        catch
        {
            // Fail closed: unknown UAC state must never authorize a High token.
            return true;
        }
    }

    private static void ValidateUacDisabledAdminToken(IntPtr token, string expectedUserSid, string label)
    {
        int elevationType = ReadTokenInt(token, TokenElevationType);
        int tokenType = ReadTokenInt(token, TokenType);
        int integrityRid = ReadIntegrityRid(token);
        string userSid = ReadTokenUserSid(token);
        bool sameUser = String.Equals(userSid, expectedUserSid, StringComparison.OrdinalIgnoreCase);
        bool adminEnabled = IsEnabledMember(token, "S-1-5-32-544");
        bool uacEnabled = IsUacEnabled();
        if (uacEnabled || elevationType != 1 || tokenType != 1 ||
            integrityRid != 0x3000 || !sameUser || !adminEnabled)
        {
            throw new InvalidOperationException(
                "R299_" + label + "_NOT_UAC_DISABLED_SAME_USER_HIGH_ADMIN" +
                "_uacEnabled=" + uacEnabled + "_type=" + elevationType +
                "_tokenType=" + tokenType + "_integrity=0x" + integrityRid.ToString("X") +
                "_sameUser=" + sameUser + "_adminEnabled=" + adminEnabled);
        }
    }

    private static void ValidateMediumToken(IntPtr token, string expectedUserSid, string label,
        bool requirePrimary, int expectedElevationType)
    {
        int elevationType = ReadTokenInt(token, TokenElevationType);
        int tokenType = ReadTokenInt(token, TokenType);
        int impersonationLevel = tokenType == 2 ? ReadTokenInt(token, TokenImpersonationLevel) : 0;
        int integrityRid = ReadIntegrityRid(token);
        string userSid = ReadTokenUserSid(token);
        bool usableTokenType = tokenType == 1 || (!requirePrimary && tokenType == 2 && impersonationLevel >= 2);
        bool sameUser = String.Equals(userSid, expectedUserSid, StringComparison.OrdinalIgnoreCase);
        bool adminEnabled = IsEnabledMember(token, "S-1-5-32-544");
        if (elevationType != expectedElevationType || !usableTokenType ||
            integrityRid != 0x2000 || !sameUser || adminEnabled)
        {
            throw new InvalidOperationException(
                "R299_" + label + "_TOKEN_NOT_MEDIUM_SAME_USER" +
                "_type=" + elevationType + "_expectedType=" + expectedElevationType +
                "_tokenType=" + tokenType + "_impersonationLevel=" + impersonationLevel +
                "_integrity=0x" + integrityRid.ToString("X") + "_sameUser=" + sameUser +
                "_adminEnabled=" + adminEnabled);
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

    public static R299HostedProcess Start(string application, string[] arguments,
        string workingDirectory, string environmentBlock)
    {
        return Start(application, arguments, workingDirectory, environmentBlock, false);
    }

    public static R299HostedProcess Start(string application, string[] arguments,
        string workingDirectory, string environmentBlock, bool consoleAllowed)
    {
        if (String.IsNullOrWhiteSpace(application) || !System.IO.Path.IsPathRooted(application))
            throw new ArgumentException("R299_APPLICATION_MUST_BE_ABSOLUTE", "application");
        if (String.IsNullOrWhiteSpace(workingDirectory) || !System.IO.Path.IsPathRooted(workingDirectory))
            throw new ArgumentException("R299_WORKING_DIRECTORY_MUST_BE_ABSOLUTE", "workingDirectory");
        if (consoleAllowed)
        {
            // Only the trusted, disposable-runner crash fixture uses a console-subsystem
            // executable. Never change process flags for the real GUI Setup /update.
            string trustedConsoleHost = System.IO.Path.Combine(
                Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");
            if (!String.Equals(System.IO.Path.GetFullPath(application), trustedConsoleHost,
                    StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("R299_CONSOLE_ONLY_ALLOWED_FOR_TRUSTED_WINDOWS_POWERSHELL", "application");
        }
        if (String.IsNullOrEmpty(environmentBlock) || environmentBlock.Length < 2 ||
            environmentBlock[environmentBlock.Length - 1] != '\0' ||
            environmentBlock[environmentBlock.Length - 2] != '\0')
            throw new ArgumentException("R299_ENVIRONMENT_BLOCK_MUST_END_WITH_DOUBLE_NUL", "environmentBlock");

        IntPtr parentToken = IntPtr.Zero;
        IntPtr linkedBuffer = IntPtr.Zero;
        IntPtr linkedToken = IntPtr.Zero;
        IntPtr restrictedToken = IntPtr.Zero;
        IntPtr sourceToken = IntPtr.Zero;
        IntPtr primaryToken = IntPtr.Zero;
        IntPtr environment = IntPtr.Zero;
        PROCESS_INFORMATION processInfo = new PROCESS_INFORMATION();
        string tokenSource = null;
        string creationMethod = null;
        int targetElevationType = 0;
        bool createWithExplicitToken = false;
        bool expectedRestricted = false;
        bool expectedUacDisabledAdmin = false;
        bool uacEnabled = IsUacEnabled();
        try
        {
            if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY | TOKEN_DUPLICATE | TOKEN_ADJUST_DEFAULT, out parentToken))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_OPEN_PARENT_TOKEN_FAILED");

            int parentElevationType = ReadTokenInt(parentToken, TokenElevationType);
            int parentIntegrityRid = ReadIntegrityRid(parentToken);
            string parentSid = ReadTokenUserSid(parentToken);

            if (parentElevationType == 2 && parentIntegrityRid >= 0x3000)
            {
                linkedBuffer = QueryTokenBuffer(parentToken, TokenLinkedToken);
                linkedToken = Marshal.ReadIntPtr(linkedBuffer);
                if (linkedToken == IntPtr.Zero) throw new InvalidOperationException("R299_LINKED_LIMITED_TOKEN_MISSING");
                ValidateMediumToken(linkedToken, parentSid, "LINKED", false, 3);
                sourceToken = linkedToken;
                targetElevationType = 3;
                tokenSource = "LINKED_LIMITED_TOKEN";
                createWithExplicitToken = true;
            }
            else if ((parentElevationType == 3 || parentElevationType == 1) && parentIntegrityRid == 0x2000)
            {
                ValidateMediumToken(parentToken, parentSid, "PARENT_MEDIUM", true, parentElevationType);
                targetElevationType = parentElevationType;
                tokenSource = "CURRENT_MEDIUM_TOKEN";
            }
            else if (parentElevationType == 1 && parentIntegrityRid >= 0x3000 && !uacEnabled)
            {
                // UAC-disabled Windows has no separate filtered Medium token.
                // Preserve the same-user High admin token that R385 explicitly allows.
                ValidateUacDisabledAdminToken(parentToken, parentSid, "PARENT_UAC_DISABLED_ADMIN");
                targetElevationType = parentElevationType;
                sourceToken = parentToken;
                tokenSource = "CURRENT_UAC_DISABLED_ADMIN_TOKEN";
                expectedUacDisabledAdmin = true;
            }
            else if (parentElevationType == 1 && parentIntegrityRid >= 0x3000)
            {
                restrictedToken = CreateRestrictedMediumToken(parentToken);
                targetElevationType = ReadTokenInt(restrictedToken, TokenElevationType);
                if (targetElevationType != 1 && targetElevationType != 3)
                    throw new InvalidOperationException("R299_RESTRICTED_MEDIUM_TOKEN_UNEXPECTED_ELEVATION_TYPE_" + targetElevationType);
                ValidateMediumToken(restrictedToken, parentSid, "RESTRICTED", true, targetElevationType);
                sourceToken = restrictedToken;
                tokenSource = "RESTRICTED_MEDIUM_TOKEN_FROM_DEFAULT_HIGH_PARENT";
                createWithExplicitToken = true;
                expectedRestricted = true;
            }
            else
            {
                throw new InvalidOperationException(
                    "R299_PARENT_TOKEN_CANNOT_PRODUCE_MEDIUM_CHILD_type=" + parentElevationType +
                    "_integrity=0x" + parentIntegrityRid.ToString("X"));
            }

            if (createWithExplicitToken)
            {
                const uint requiredTokenAccess = TOKEN_QUERY | TOKEN_DUPLICATE | TOKEN_ASSIGN_PRIMARY;
                if (!DuplicateTokenEx(sourceToken, requiredTokenAccess, IntPtr.Zero,
                    2, 1, out primaryToken))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_DUPLICATE_EXPLICIT_MEDIUM_PRIMARY_TOKEN_FAILED");
                ValidateMediumToken(primaryToken, parentSid, "DUPLICATED", true, targetElevationType);
                if (expectedRestricted && IsEnabledMember(primaryToken, "S-1-5-32-544"))
                    throw new InvalidOperationException("R299_DUPLICATED_RESTRICTED_TOKEN_ADMIN_GROUP_ENABLED");
            }

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

            // CREATE_NO_WINDOW can make a restricted-token console-subsystem child
            // terminate in the loader with STATUS_DLL_INIT_FAILED (0xC0000142).
            // Preserve the old no-window behavior for Setup; allow normal console
            // attach/creation only for the trusted PowerShell crash fixture.
            uint creationFlags = CREATE_UNICODE_ENVIRONMENT | (consoleAllowed ? 0u : CREATE_NO_WINDOW);
            bool created;
            if (expectedUacDisabledAdmin)
            {
                StringBuilder adminCommand = new StringBuilder(command);
                created = CreateProcessW(application, adminCommand, IntPtr.Zero, IntPtr.Zero, false,
                    creationFlags, environment, workingDirectory, ref startup, out processInfo);
                if (!created)
                {
                    int adminError = Marshal.GetLastWin32Error();
                    throw new Win32Exception(adminError,
                        "R299_CREATE_PROCESS_UAC_DISABLED_ADMIN_CURRENT_TOKEN_FAILED_WIN32_" + adminError);
                }
                creationMethod = "CREATE_PROCESS_CURRENT_UAC_DISABLED_ADMIN_TOKEN";
            }
            else if (expectedRestricted)
            {
                StringBuilder asUserCommand = new StringBuilder(command);
                created = CreateProcessAsUserW(primaryToken, application, asUserCommand,
                    IntPtr.Zero, IntPtr.Zero, false, creationFlags, environment,
                    workingDirectory, ref startup, out processInfo);
                if (created)
                {
                    creationMethod = "CREATE_PROCESS_AS_USER";
                }
                else
                {
                    int asUserError = Marshal.GetLastWin32Error();
                    if (asUserError != 1314)
                        throw new Win32Exception(asUserError,
                            "R299_CREATE_PROCESS_AS_USER_RESTRICTED_TOKEN_FAILED_WIN32_" + asUserError);

                    StringBuilder fallbackCommand = new StringBuilder(command);
                    created = CreateProcessWithTokenW(primaryToken, 1, application, fallbackCommand,
                        creationFlags, environment, workingDirectory, ref startup, out processInfo);
                    if (!created)
                    {
                        int fallbackError = Marshal.GetLastWin32Error();
                        throw new Win32Exception(fallbackError,
                            "R299_CREATE_PROCESS_RESTRICTED_TOKEN_FAILED_ASUSER_WIN32_" +
                            asUserError + "_WITHTOKEN_WIN32_" + fallbackError);
                    }
                    creationMethod = "CREATE_PROCESS_WITH_TOKEN_FALLBACK_AFTER_ASUSER_1314";
                }
            }
            else if (createWithExplicitToken)
            {
                StringBuilder explicitCommand = new StringBuilder(command);
                created = CreateProcessWithTokenW(primaryToken, 1, application, explicitCommand,
                    creationFlags, environment, workingDirectory, ref startup, out processInfo);
                if (!created)
                {
                    int explicitError = Marshal.GetLastWin32Error();
                    throw new Win32Exception(explicitError,
                        "R299_CREATE_PROCESS_WITH_EXPLICIT_MEDIUM_TOKEN_FAILED_WIN32_" + explicitError);
                }
                creationMethod = "CREATE_PROCESS_WITH_TOKEN";
            }
            else
            {
                StringBuilder currentCommand = new StringBuilder(command);
                created = CreateProcessW(application, currentCommand, IntPtr.Zero, IntPtr.Zero, false,
                    creationFlags, environment, workingDirectory, ref startup, out processInfo);
                if (!created)
                {
                    int currentError = Marshal.GetLastWin32Error();
                    throw new Win32Exception(currentError,
                        "R299_CREATE_PROCESS_WITH_CURRENT_MEDIUM_TOKEN_FAILED_WIN32_" + currentError);
                }
                creationMethod = "CREATE_PROCESS_CURRENT_TOKEN";
            }

            IntPtr childToken = IntPtr.Zero;
            int childElevationType = 0;
            int childIntegrityRid = 0;
            bool childAdministratorsEnabled = false;
            try
            {
                if (!OpenProcessToken(processInfo.hProcess, TOKEN_QUERY | TOKEN_DUPLICATE, out childToken))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "R299_OPEN_CREATED_CHILD_TOKEN_FAILED");
                if (expectedUacDisabledAdmin)
                    ValidateUacDisabledAdminToken(childToken, parentSid, "CREATED_UAC_DISABLED_ADMIN_CHILD");
                else
                    ValidateMediumToken(childToken, parentSid, "CREATED_CHILD", true, targetElevationType);
                if (expectedRestricted && IsEnabledMember(childToken, "S-1-5-32-544"))
                    throw new InvalidOperationException("R299_CREATED_RESTRICTED_CHILD_ADMIN_GROUP_ENABLED");
                childElevationType = ReadTokenInt(childToken, TokenElevationType);
                childIntegrityRid = ReadIntegrityRid(childToken);
                childAdministratorsEnabled = IsEnabledMember(childToken, "S-1-5-32-544");
            }
            finally
            {
                if (childToken != IntPtr.Zero) CloseHandle(childToken);
            }

            R299HostedProcess result = new R299HostedProcess(
                processInfo.hProcess, processInfo.dwProcessId, tokenSource, creationMethod,
                childElevationType, childIntegrityRid, childAdministratorsEnabled, uacEnabled,
                consoleAllowed);
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
            if (restrictedToken != IntPtr.Zero) CloseHandle(restrictedToken);
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
