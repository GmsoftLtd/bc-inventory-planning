/// <summary>
/// Creates the setup record with defaults on first install, so every page and
/// calculator finds a usable configuration immediately.
/// </summary>
codeunit 50519 "IPL Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "IPL Setup";
    begin
        Setup.GetSetup();
    end;
}
