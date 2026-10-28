namespace GMSoft.InventoryPlanning.Demo;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;

/// <summary>
/// Creates seven demo items with a year of sales history, one per demand
/// pattern the calculators and the policy advisor distinguish: smooth, erratic,
/// intermittent, lumpy, perishable, ramping up, and too new to trust.
/// Posting groups and the base unit of measure are copied from an existing
/// inventory item, so it runs in any company that has one (CRONUS has many).
/// History is posted with the item journal (one purchase for opening stock,
/// then one sale per demand day) and is deterministic: the same seed per item
/// gives the same numbers every time. Items that already exist are skipped.
/// </summary>
codeunit 60000 "GSO Demo Data"
{
    var
        SourceItem: Record Item;
        DocumentNoTxt: Label 'GSODEMO', Locked = true;
        DaysFormulaTxt: Label '<%1D>', Locked = true, Comment = '%1 = number of days';
        NoSourceItemErr: Label 'The demo data copies posting groups from an existing inventory item, but this company has none. Create one inventory item with an inventory posting group and a general product posting group, then try again.';

    /// <summary>
    /// Creates the demo items and posts their history. Returns the number of
    /// items created; existing demo items are left as they are.
    /// </summary>
    procedure CreateDemoData() Created: Integer
    begin
        FindSourceItem();
        Created += CreateDemoItem('GSODEMO-SMOOTH', 'Demo: smooth demand', 25, 7, "Reordering Policy"::"Fixed Reorder Qty.", 75, 8, 14, 0, 365, 0, 11);
        Created += CreateDemoItem('GSODEMO-ERRATIC', 'Demo: erratic demand', 40, 10, "Reordering Policy"::" ", 70, 1, 60, 0, 365, 0, 23);
        Created += CreateDemoItem('GSODEMO-INTERMIT', 'Demo: intermittent demand', 120, 14, "Reordering Policy"::" ", 18, 4, 6, 0, 365, 0, 37);
        Created += CreateDemoItem('GSODEMO-LUMPY', 'Demo: lumpy demand', 85, 21, "Reordering Policy"::" ", 15, 1, 90, 0, 365, 0, 41);
        Created += CreateDemoItem('GSODEMO-PERISH', 'Demo: perishable, 30-day shelf life', 6, 3, "Reordering Policy"::"Maximum Qty.", 80, 20, 35, 0, 365, 30, 53);
        Created += CreateDemoItem('GSODEMO-RAMP', 'Demo: demand ramping up', 15, 7, "Reordering Policy"::"Fixed Reorder Qty.", 65, 4, 8, 150, 365, 0, 67);
        Created += CreateDemoItem('GSODEMO-NEW', 'Demo: new item, little history', 30, 7, "Reordering Policy"::" ", 60, 2, 5, 0, 20, 0, 79);
    end;

    local procedure FindSourceItem()
    begin
        SourceItem.SetRange(Type, SourceItem.Type::Inventory);
        SourceItem.SetFilter("Inventory Posting Group", '<>%1', '');
        SourceItem.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        SourceItem.SetFilter("Base Unit of Measure", '<>%1', '');
        SourceItem.SetFilter("No.", '<>%1', 'GSODEMO-*');
        if not SourceItem.FindFirst() then
            Error(NoSourceItemErr);
    end;

    /// <param name="DemandDayPct">Chance, in percent, that a day has demand.</param>
    /// <param name="RampPct">Growth of the daily quantity from the first to the last day.</param>
    /// <param name="HistoryDays">Days of history ending on the work date.</param>
    /// <param name="ShelfLifeDays">Expiration calculation in days; 0 for none.</param>
    local procedure CreateDemoItem(ItemNo: Code[20]; Description: Text[100]; UnitCost: Decimal; LeadTimeDays: Integer; Policy: Enum "Reordering Policy"; DemandDayPct: Integer; MinQty: Integer; MaxQty: Integer; RampPct: Integer; HistoryDays: Integer; ShelfLifeDays: Integer; Seed: Integer): Integer
    var
        Item: Record Item;
        DailyQty: List of [Decimal];
        StartDate: Date;
        TotalQty: Decimal;
        Qty: Decimal;
        Day: Integer;
    begin
        if Item.Get(ItemNo) then
            exit(0);

        InsertItem(ItemNo, Description, UnitCost, LeadTimeDays, Policy, ShelfLifeDays);

        Randomize(Seed);
        for Day := 1 to HistoryDays do begin
            Qty := 0;
            if Random(100) <= DemandDayPct then
                Qty := Round((MinQty + Random(MaxQty - MinQty + 1) - 1) * (1 + RampPct / 100 * Day / HistoryDays), 1);
            DailyQty.Add(Qty);
            TotalQty += Qty;
        end;

        StartDate := WorkDate() - HistoryDays + 1;
        PostItemJnlLine(ItemNo, "Item Ledger Entry Type"::Purchase, StartDate - 1, Round(TotalQty * 1.2, 1) + MaxQty, UnitCost);
        for Day := 1 to HistoryDays do
            if DailyQty.Get(Day) > 0 then
                PostItemJnlLine(ItemNo, "Item Ledger Entry Type"::Sale, StartDate + Day - 1, DailyQty.Get(Day), Round(UnitCost * 1.6, 0.01));

        Commit();
        exit(1);
    end;

    local procedure InsertItem(ItemNo: Code[20]; Description: Text[100]; UnitCost: Decimal; LeadTimeDays: Integer; Policy: Enum "Reordering Policy"; ShelfLifeDays: Integer)
    var
        Item: Record Item;
    begin
        Item.Init();
        Item."No." := ItemNo;
        Item.Insert(true);
        Item.Validate(Description, Description);
        Item.Validate(Type, Item.Type::Inventory);
        Item.Validate("Base Unit of Measure", SourceItem."Base Unit of Measure");
        Item.Validate("Inventory Posting Group", SourceItem."Inventory Posting Group");
        Item.Validate("Gen. Prod. Posting Group", SourceItem."Gen. Prod. Posting Group");
        Item.Validate("VAT Prod. Posting Group", SourceItem."VAT Prod. Posting Group");
        Item.Validate("Unit Cost", UnitCost);
        Item.Validate("Last Direct Cost", UnitCost);
        Item.Validate("Unit Price", Round(UnitCost * 1.6, 0.01));
        Item.Validate("Replenishment System", Item."Replenishment System"::Purchase);
        Evaluate(Item."Lead Time Calculation", StrSubstNo(DaysFormulaTxt, LeadTimeDays));
        if ShelfLifeDays > 0 then
            Evaluate(Item."Expiration Calculation", StrSubstNo(DaysFormulaTxt, ShelfLifeDays));
        Item.Validate("Reordering Policy", Policy);
        Item.Modify(true);
    end;

    local procedure PostItemJnlLine(ItemNo: Code[20]; EntryType: Enum "Item Ledger Entry Type"; PostingDate: Date; Qty: Decimal; UnitAmount: Decimal)
    var
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
    begin
        ItemJnlLine.Init();
        ItemJnlLine.Validate("Posting Date", PostingDate);
        ItemJnlLine."Document Date" := PostingDate;
        ItemJnlLine."Document No." := DocumentNoTxt;
        ItemJnlLine.Validate("Entry Type", EntryType);
        ItemJnlLine.Validate("Item No.", ItemNo);
        ItemJnlLine.Validate(Quantity, Qty);
        ItemJnlLine.Validate("Unit Amount", UnitAmount);
        ItemJnlPostLine.RunWithCheck(ItemJnlLine);
    end;
}
