namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using System.DataAdministration;
using System.Environment.Configuration;
using System.Reflection;
using System.Security.AccessControl;
using System.TestLibraries.Utilities;
using System.Threading;
using System.Upgrade;

/// <summary>
/// Everything around the calculators: the scheduled job and its parameter,
/// the upgrade steps, install registrations, setup defaults and the two
/// permission sets.
/// </summary>
codeunit 50209 "GSO Lifecycle Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "GSO Test Library";
        AppIdTxt: Label '16b338f4-22c0-4426-8d1b-946290d76d30', Locked = true;
        UserRoleTxt: Label 'GSO - USER', Locked = true;
        AdminRoleTxt: Label 'GSO', Locked = true;
        UserMustRunMsg: Label 'GSO - User must be able to run %1 %2', Locked = true;
        RoleMustGrantMsg: Label '%1 must grant table data %2', Locked = true;

    local procedure CreateSmoothItem(var Item: Record Item)
    begin
        TestLib.CreateItem(Item);
        TestLib.AddSales(Item."No.", 0, 89, 1, 9, 11);
    end;

    local procedure RunScheduledJob(Parameter: Text[250])
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"GSO Job Queue";
        JobQueueEntry."Parameter String" := Parameter;
        Codeunit.Run(Codeunit::"GSO Job Queue", JobQueueEntry);
    end;

    local procedure PrepareScheduledItem(var Item: Record Item)
    var
        Setup: Record "GSO Setup";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Auto-Update Policy" := true;
        Setup.Modify(false);
        CreateSmoothItem(Item);
        TestLib.ExcludeAllItemsExcept(Item."No.", Item."No.");
    end;

    [Test]
    procedure JobQueue_SafetyStock_RunsOnlySafetyStock()
    var
        Item: Record Item;
    begin
        PrepareScheduledItem(Item);

        RunScheduledJob('SAFETYSTOCK');

        Item.Get(Item."No.");
        Assert.IsTrue(Item."Safety Stock Quantity" > 0, 'Safety stock written');
        Assert.AreEqual(0, Item."Reorder Point", 'Reorder point not run');
        Assert.AreEqual(0, Item."Reorder Quantity", 'EOQ not run');
    end;

    [Test]
    procedure JobQueue_ReorderPoint_RunsOnlyReorderPoint()
    var
        Item: Record Item;
    begin
        PrepareScheduledItem(Item);

        RunScheduledJob('REORDERPOINT');

        Item.Get(Item."No.");
        Assert.AreEqual(70, Item."Reorder Point", 'Reorder point written (no safety stock stored yet)');
        Assert.AreEqual(0, Item."Safety Stock Quantity", 'Safety stock not run');
        Assert.AreEqual(0, Item."Reorder Quantity", 'EOQ not run');
    end;

    [Test]
    procedure JobQueue_EOQ_RunsOnlyEOQ()
    var
        Item: Record Item;
    begin
        PrepareScheduledItem(Item);

        RunScheduledJob('EOQ');

        Item.Get(Item."No.");
        Assert.IsTrue(Item."Reorder Quantity" > 0, 'EOQ written');
        Assert.AreEqual(0, Item."Reorder Point", 'Reorder point not run');
        Assert.AreEqual(0, Item."Safety Stock Quantity", 'Safety stock not run');
    end;

    [Test]
    procedure JobQueue_Advisor_RunsOnlyAdvisor()
    var
        Item: Record Item;
    begin
        PrepareScheduledItem(Item);

        RunScheduledJob('ADVISOR');

        Item.Get(Item."No.");
        Assert.AreEqual(Item."Reordering Policy"::"Fixed Reorder Qty.", Item."Reordering Policy", 'Policy advised and written');
        Assert.AreEqual(0, Item."Reorder Point", 'Reorder point not run');
    end;

    [Test]
    procedure JobQueue_BlankParameter_RunsAll()
    var
        Item: Record Item;
    begin
        PrepareScheduledItem(Item);

        RunScheduledJob('');

        Item.Get(Item."No.");
        Assert.IsTrue(Item."Safety Stock Quantity" > 0, 'Safety stock written');
        Assert.AreEqual(70 + Item."Safety Stock Quantity", Item."Reorder Point", 'Reorder point written on the new safety stock');
        Assert.IsTrue(Item."Reorder Quantity" > 0, 'EOQ written');
    end;

    [Test]
    procedure JobQueue_Parameter_TrimmedAndCaseInsensitive()
    var
        Item: Record Item;
    begin
        PrepareScheduledItem(Item);

        RunScheduledJob('  safetystock ');

        Item.Get(Item."No.");
        Assert.IsTrue(Item."Safety Stock Quantity" > 0, 'Lower case with spaces still selects safety stock');
        Assert.AreEqual(0, Item."Reorder Point", 'And only safety stock');
    end;

    [Test]
    procedure Upgrade_MovesJobQueueEntriesToNewCodeunitId()
    var
        Moved, OtherCodeunit, SameIdReport : Record "Job Queue Entry";
        GSOUpgrade: Codeunit "GSO Upgrade";
    begin
        TestLib.InitSetup();
        InsertJobQueueEntry(Moved, Moved."Object Type to Run"::Codeunit, 73030593);
        InsertJobQueueEntry(OtherCodeunit, OtherCodeunit."Object Type to Run"::Codeunit, 73030580);
        InsertJobQueueEntry(SameIdReport, SameIdReport."Object Type to Run"::Report, 73030593);

        GSOUpgrade.MoveJobQueueEntriesToNewCodeunitId();

        Moved.Get(Moved.ID);
        OtherCodeunit.Get(OtherCodeunit.ID);
        SameIdReport.Get(SameIdReport.ID);
        Assert.AreEqual(Codeunit::"GSO Job Queue", Moved."Object ID to Run", 'Entries running the old ID run the new GSO Job Queue');
        Assert.AreEqual(73030580, OtherCodeunit."Object ID to Run", 'Other codeunits untouched');
        Assert.AreEqual(73030593, SameIdReport."Object ID to Run", 'A report with the same number is not a codeunit');
    end;

    local procedure InsertJobQueueEntry(var JobQueueEntry: Record "Job Queue Entry"; ObjectType: Option; ObjectId: Integer)
    begin
        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry."Object Type to Run" := ObjectType;
        JobQueueEntry."Object ID to Run" := ObjectId;
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry.Insert(false);
    end;

    [Test]
    procedure Upgrade_MaxInvTrendDefaults_FillsBlanks()
    var
        Setup: Record "GSO Setup";
        GSOUpgrade: Codeunit "GSO Upgrade";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Trend Warning Threshold %" := 0;
        Setup."Apply Maximum Inventory" := false;
        Setup.Modify(false);

        GSOUpgrade.ApplyMaxInvTrendDefaults();

        Setup.Get();
        Assert.AreEqual(30, Setup."Trend Warning Threshold %", 'A blank threshold gets the default');
        Assert.IsTrue(Setup."Apply Maximum Inventory", 'Apply Maximum Inventory switched on');
    end;

    [Test]
    procedure Upgrade_MaxInvTrendDefaults_KeepsChosenThreshold()
    var
        Setup: Record "GSO Setup";
        GSOUpgrade: Codeunit "GSO Upgrade";
    begin
        TestLib.InitSetup();
        Setup.GetSetup();
        Setup."Trend Warning Threshold %" := 45;
        Setup.Modify(false);

        GSOUpgrade.ApplyMaxInvTrendDefaults();

        Setup.Get();
        Assert.AreEqual(45, Setup."Trend Warning Threshold %", 'A chosen threshold is kept');
    end;

    [Test]
    procedure Upgrade_MaxInvTrendDefaults_NoSetup_CreatesNothing()
    var
        Setup: Record "GSO Setup";
        GSOUpgrade: Codeunit "GSO Upgrade";
    begin
        Setup.DeleteAll(false);

        GSOUpgrade.ApplyMaxInvTrendDefaults();

        Assert.IsTrue(Setup.IsEmpty(), 'No setup record is created by the upgrade');
    end;

    [Test]
    procedure FreshInstall_MarksEveryUpgradeStepDone()
    var
        GSOUpgrade: Codeunit "GSO Upgrade";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        GSOUpgrade.RegisterFreshInstallTags();

        Assert.IsTrue(UpgradeTag.HasUpgradeTag('GSO-UPG-MaxInvTrend-20260810'), 'MaxInvTrend step marked done');
        Assert.IsTrue(UpgradeTag.HasUpgradeTag('GSO-INVPL-JobQueueCodeunitId-1.29.2.0'), 'Job Queue step marked done');
    end;

    [Test]
    procedure Install_LogAllowedForRetentionPolicies()
    var
        RetenPolAllowedTables: Codeunit "Reten. Pol. Allowed Tables";
    begin
        Assert.IsTrue(RetenPolAllowedTables.IsAllowedTable(Database::"GSO Calculation Log"), 'The calculation log can be given a retention policy');
    end;

    [Test]
    procedure Install_SetupListedUnderManualSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
        ManualSetup: TestPage "Manual Setup";
    begin
        ManualSetup.OpenView(); // raises OnRegisterManualSetup
        ManualSetup.Close();

        Assert.IsTrue(GuidedExperience.Exists(Enum::"Guided Experience Type"::"Manual Setup", ObjectType::Page, Page::"GSO Setup"), 'Setup page listed under Manual Setup');
    end;

    [Test]
    procedure Setup_GetSetup_CreatesDefaults()
    var
        Setup: Record "GSO Setup";
    begin
        Setup.DeleteAll(false);

        Setup.GetSetup();

        Assert.AreEqual(365, Setup."History Window (Days)", 'History window');
        Assert.AreEqual(7, Setup."Default Lead Time (Days)", 'Default lead time');
        Assert.AreEqual(95, Setup."Default Service Level %", 'Service level');
        Assert.AreEqual(50, Setup."Ordering Cost", 'Ordering cost');
        Assert.AreEqual(0.25, Setup."Holding Rate", 'Holding rate');
        Assert.AreEqual(6, Setup."Max EOQ Months", 'Max EOQ months');
        Assert.AreEqual(1.32, Setup."Lumpy ADI Threshold", 'ADI threshold');
        Assert.AreEqual(0.49, Setup."Erratic CV2 Threshold", 'CV2 threshold');
        Assert.IsTrue(Setup."Apply Maximum Inventory", 'Apply Maximum Inventory');
        Assert.IsTrue(Setup."Apply EOQ", 'Apply EOQ');
        Assert.IsTrue(Setup."Apply Reorder Point", 'Apply Reorder Point');
        Assert.IsTrue(Setup."Include Safety Stock", 'Include Safety Stock');
        Assert.IsTrue(Setup."Perishable Means Max Qty.", 'Perishable Means Max Qty.');
        Assert.IsFalse(Setup."Auto-Update Policy", 'Auto-update off by default');
    end;

    [Test]
    procedure Setup_GetSetup_KeepsOneRecord()
    var
        Setup: Record "GSO Setup";
    begin
        Setup.DeleteAll(false);

        Setup.GetSetup();
        Setup."Ordering Cost" := 75;
        Setup.Modify(false);
        Clear(Setup);
        Setup.GetSetup();

        Assert.AreEqual(1, Setup.Count(), 'A singleton');
        Assert.AreEqual(75, Setup."Ordering Cost", 'An existing record is read, not reset');
    end;

    [Test]
    procedure Permissions_UserCanRunEveryCodeunitAndPage()
    var
        AllObj: Record AllObj;
        ExpandedPermission: Record "Expanded Permission";
        Info: ModuleInfo;
        ObjectTypeNo: Integer;
    begin
        NavApp.GetModuleInfo(AppId(), Info);
        AllObj.SetRange("App Package ID", Info.PackageId());
        AllObj.SetFilter("Object Type", '%1|%2', AllObj."Object Type"::Codeunit, AllObj."Object Type"::Page);
        Assert.IsTrue(AllObj.FindSet(), 'The app has codeunits and pages');
        repeat
            ObjectTypeNo := AllObj."Object Type";
            ExpandedPermission.SetRange("App ID", AppId());
            ExpandedPermission.SetRange("Role ID", UserRoleTxt);
            ExpandedPermission.SetRange("Object Type", ObjectTypeNo);
            ExpandedPermission.SetRange("Object ID", AllObj."Object ID");
            ExpandedPermission.SetRange("Execute Permission", ExpandedPermission."Execute Permission"::Yes);
            Assert.IsFalse(ExpandedPermission.IsEmpty(), StrSubstNo(UserMustRunMsg, AllObj."Object Type", AllObj."Object Name"));
        until AllObj.Next() = 0;
    end;

    [Test]
    procedure Permissions_UserReadsSetupAndLogOnly()
    var
        ExpandedPermission: Record "Expanded Permission";
    begin
        FindTableData(UserRoleTxt, Database::"GSO Setup", ExpandedPermission);
        Assert.AreEqual(ExpandedPermission."Read Permission"::Yes, ExpandedPermission."Read Permission", 'User reads setup');
        Assert.AreEqual(ExpandedPermission."Modify Permission"::" ", ExpandedPermission."Modify Permission", 'User cannot change setup');

        FindTableData(UserRoleTxt, Database::"GSO Calculation Log", ExpandedPermission);
        Assert.AreEqual(ExpandedPermission."Read Permission"::Yes, ExpandedPermission."Read Permission", 'User reads the log');
        Assert.AreEqual(ExpandedPermission."Delete Permission"::" ", ExpandedPermission."Delete Permission", 'User cannot delete log entries');

        FindTableData(UserRoleTxt, Database::"GSO Planning Proposal", ExpandedPermission);
        Assert.AreEqual(ExpandedPermission."Insert Permission"::Yes, ExpandedPermission."Insert Permission", 'User fills the worksheet buffer');
        Assert.AreEqual(ExpandedPermission."Delete Permission"::Yes, ExpandedPermission."Delete Permission", 'User clears the worksheet buffer');
    end;

    [Test]
    procedure Permissions_AdminManagesSetupAndLog()
    var
        ExpandedPermission: Record "Expanded Permission";
    begin
        FindTableData(AdminRoleTxt, Database::"GSO Setup", ExpandedPermission);
        Assert.AreEqual(ExpandedPermission."Modify Permission"::Yes, ExpandedPermission."Modify Permission", 'Admin changes setup');

        FindTableData(AdminRoleTxt, Database::"GSO Calculation Log", ExpandedPermission);
        Assert.AreEqual(ExpandedPermission."Delete Permission"::Yes, ExpandedPermission."Delete Permission", 'Admin deletes log entries');

        ExpandedPermission.Reset();
        ExpandedPermission.SetRange("App ID", AppId());
        ExpandedPermission.SetRange("Role ID", AdminRoleTxt);
        ExpandedPermission.SetRange("Object Type", ExpandedPermission."Object Type"::Codeunit);
        ExpandedPermission.SetRange("Object ID", Codeunit::"GSO Run All");
        Assert.IsFalse(ExpandedPermission.IsEmpty(), 'Admin includes everything the user can do');
    end;

    local procedure FindTableData(RoleId: Code[30]; TableId: Integer; var ExpandedPermission: Record "Expanded Permission")
    begin
        ExpandedPermission.Reset();
        ExpandedPermission.SetRange("App ID", AppId());
        ExpandedPermission.SetRange("Role ID", RoleId);
        ExpandedPermission.SetRange("Object Type", ExpandedPermission."Object Type"::"Table Data");
        ExpandedPermission.SetRange("Object ID", TableId);
        Assert.IsTrue(ExpandedPermission.FindFirst(), StrSubstNo(RoleMustGrantMsg, RoleId, TableId));
    end;

    local procedure AppId(): Guid
    begin
        exit(AppIdTxt);
    end;
}
