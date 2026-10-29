namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Purchases.History;

/// <summary>
/// Shared setup and data builders for the Inventory Planning tests.
///
/// Demand and receipt history is written as ledger rows directly instead of
/// being posted: the calculators read only Item No., Posting Date, Entry Type
/// and Quantity from Item Ledger Entry (and Order/Posting Date from receipt
/// lines), so a row-level mock tests the same code paths in milliseconds, and
/// it is the only practical way to create Consumption and Assembly
/// Consumption demand. GSO Calculator Tests keeps the end-to-end posting path.
/// </summary>
codeunit 50202 "GSO Test Library"
{
    // Online, the license grants ledger inserts only indirectly, through an
    // object that declares them, as the posting codeunits do.
    Permissions = tabledata "Item Ledger Entry" = ri,
                  tabledata "Purch. Rcpt. Line" = ri;

    var
        LibraryInventory: Codeunit "Library - Inventory";
        ReceiptCounter: Integer;

    /// <summary>
    /// Puts setup into the known state every test starts from and clears the
    /// SingleInstance caches. Per-test rollback reverts setup, so this runs
    /// for every test.
    /// </summary>
    procedure InitSetup()
    var
        Setup: Record "GSO Setup";
        DemandStats: Codeunit "GSO Demand Statistics";
        Provider: Codeunit "GSO Planning Provider";
    begin
        Setup.GetSetup();
        Setup."History Window (Days)" := 90;
        Setup."Min Demand Observations" := 5;
        Setup."Round Up Results" := true;
        Setup."Log History" := true;
        Setup."Skip Make-to-Order" := true;
        Setup."Default Lead Time (Days)" := 7;
        Setup."Include Consumption Demand" := false;
        Setup."Trend Warning Threshold %" := 30;
        Setup."Default Service Level %" := 95;
        Setup."Apply Safety Stock" := true;
        Setup."Include Safety Stock" := true;
        Setup."Apply Reorder Point" := true;
        Setup."Set Policy When None" := true;
        Setup."Apply Maximum Inventory" := true;
        Setup."Ordering Cost" := 50;
        Setup."Holding Rate" := 0.25;
        Setup."Max EOQ Months" := 24;
        Setup."EOQ Write Target" := Setup."EOQ Write Target"::"Reorder Quantity";
        Setup."Cost Source" := Setup."Cost Source"::"Last Direct Cost";
        Setup."Apply EOQ" := true;
        Setup."Lumpy ADI Threshold" := 1.32;
        Setup."Erratic CV2 Threshold" := 0.49;
        Setup."Perishable Means Max Qty." := true;
        Setup."Auto-Update Policy" := false;
        Setup."Dynamic Provider Enabled" := false;
        Setup.Modify(false);
        DemandStats.ClearCache();
        Provider.ClearCache();
    end;

    procedure ClearCaches()
    var
        DemandStats: Codeunit "GSO Demand Statistics";
        Provider: Codeunit "GSO Planning Provider";
    begin
        DemandStats.ClearCache();
        Provider.ClearCache();
    end;

    /// <summary>
    /// A purchased inventory item with a Last Direct Cost of 20 and no
    /// planning parameters.
    /// </summary>
    procedure CreateItem(var Item: Record Item)
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate("Last Direct Cost", 20);
        Item.Modify(true);
    end;

    /// <summary>
    /// CreateItem plus 10 units of sales on each of the 30 days before the
    /// work date: 300 units, average 300/90 per day in the default window.
    /// </summary>
    procedure CreateItemWithDailySales(var Item: Record Item)
    begin
        CreateItem(Item);
        AddSales(Item."No.", 1, 30, 1, 10, 10);
    end;

    /// <summary>
    /// Sales on every Nth day from FirstDaysAgo to LastDaysAgo before the work
    /// date, alternating between Qty1 and Qty2 (equal for constant sizes).
    /// </summary>
    procedure AddSales(ItemNo: Code[20]; FirstDaysAgo: Integer; LastDaysAgo: Integer; EveryNthDay: Integer; Qty1: Decimal; Qty2: Decimal)
    var
        DaysAgo: Integer;
        UseFirst: Boolean;
    begin
        UseFirst := true;
        for DaysAgo := FirstDaysAgo to LastDaysAgo do
            if DaysAgo mod EveryNthDay = 0 then begin
                if UseFirst then
                    AddSale(ItemNo, DaysAgo, Qty1)
                else
                    AddSale(ItemNo, DaysAgo, Qty2);
                UseFirst := not UseFirst;
            end;
    end;

    /// <summary>
    /// A sale of Qty units DaysAgo days before the work date (an outbound
    /// ledger row, so the ledger quantity is negative).
    /// </summary>
    procedure AddSale(ItemNo: Code[20]; DaysAgo: Integer; Qty: Decimal)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        AddLedgerEntry(ItemNo, DaysAgo, ItemLedgerEntry."Entry Type"::Sale, -Qty);
    end;

    /// <summary>
    /// A ledger row with the signed quantity as posted: negative for
    /// outbound, positive for returns and receipts.
    /// </summary>
    procedure AddLedgerEntry(ItemNo: Code[20]; DaysAgo: Integer; EntryType: Enum "Item Ledger Entry Type"; LedgerQty: Decimal)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        LastEntry: Record "Item Ledger Entry";
    begin
        LastEntry.SetLoadFields("Entry No.");
        if LastEntry.FindLast() then;
        ItemLedgerEntry.Init();
        ItemLedgerEntry."Entry No." := LastEntry."Entry No." + 1;
        ItemLedgerEntry."Item No." := ItemNo;
        ItemLedgerEntry."Posting Date" := WorkDate() - DaysAgo;
        ItemLedgerEntry."Entry Type" := EntryType;
        ItemLedgerEntry.Quantity := LedgerQty;
        ItemLedgerEntry.Positive := LedgerQty > 0;
        ItemLedgerEntry.Insert(false);
    end;

    /// <summary>
    /// A posted receipt line for the item, ordered OrderDaysAgo and received
    /// ReceiptDaysAgo before the work date. 0 means a blank date.
    /// </summary>
    procedure AddReceipt(ItemNo: Code[20]; OrderDaysAgo: Integer; ReceiptDaysAgo: Integer)
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
    begin
        ReceiptCounter += 1;
        PurchRcptLine.Init();
        PurchRcptLine."Document No." := CopyStr('GSOT-' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(PurchRcptLine."Document No."));
        PurchRcptLine."Line No." := ReceiptCounter * 10000;
        PurchRcptLine.Type := PurchRcptLine.Type::Item;
        PurchRcptLine."No." := ItemNo;
        if OrderDaysAgo <> 0 then
            PurchRcptLine."Order Date" := WorkDate() - OrderDaysAgo;
        if ReceiptDaysAgo <> 0 then
            PurchRcptLine."Posting Date" := WorkDate() - ReceiptDaysAgo;
        PurchRcptLine.Insert(false);
    end;

    procedure SetLeadTimeFormula(var Item: Record Item; FormulaText: Text)
    var
        LeadTimeFormula: DateFormula;
    begin
        Evaluate(LeadTimeFormula, FormulaText);
        Item.Validate("Lead Time Calculation", LeadTimeFormula);
        Item.Modify(true);
    end;

    /// <summary>
    /// Marks every other item as excluded, so bulk runs over all items (the
    /// scheduled job, unfiltered list actions) touch only the test's items.
    /// Rolled back with the test.
    /// </summary>
    procedure ExcludeAllItemsExcept(ItemNo1: Code[20]; ItemNo2: Code[20])
    var
        Item: Record Item;
    begin
        Item.SetFilter("No.", '<>%1&<>%2', ItemNo1, ItemNo2);
        Item.ModifyAll("GSO Exclude From Planning", true, false);
    end;

    /// <summary>
    /// The newest calculation log entry for the item and type; false when
    /// there is none.
    /// </summary>
    procedure FindLastLog(ItemNo: Code[20]; CalcType: Enum "GSO Calculation Type"; var LogEntry: Record "GSO Calculation Log"): Boolean
    begin
        LogEntry.Reset();
        LogEntry.SetRange("Item No.", ItemNo);
        LogEntry.SetRange("Calculation Type", CalcType);
        exit(LogEntry.FindLast());
    end;

    procedure CountLog(ItemNo: Code[20]): Integer
    var
        LogEntry: Record "GSO Calculation Log";
    begin
        LogEntry.SetRange("Item No.", ItemNo);
        exit(LogEntry.Count());
    end;

    /// <summary>
    /// Average daily demand of CreateItemWithDailySales in the default
    /// 90-day window.
    /// </summary>
    procedure DailySalesAvgDemand(): Decimal
    begin
        exit(300 / 90);
    end;
}
