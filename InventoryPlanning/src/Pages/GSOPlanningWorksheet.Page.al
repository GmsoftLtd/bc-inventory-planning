/// <summary>
/// The consolidation feature none of the standalone apps had: current vs
/// proposed planning values for a set of items, side by side, with selective
/// apply. Loading computes previews only; nothing is written until Apply, and
/// applies run through the calculators' validated, logged path. After an
/// apply, the affected lines refresh their "current" values in place.
/// </summary>
page 70455002 "GSO Planning Worksheet"
{
    PageType = Worksheet;
    SourceTable = "GSO Planning Proposal";
    SourceTableTemporary = true;
    Caption = 'Inventory Planning Worksheet';
    ApplicationArea = All;
    UsageCategory = Tasks;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Proposals)
            {
                field(Selected; Rec.Selected)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this item is included when you choose Apply Selected.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item number.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item description.';
                }
                field("Demand Pattern"; Rec."Demand Pattern")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the demand classification: Smooth, Erratic, Intermittent or Lumpy.';
                }
                field("Current Policy"; Rec."Current Policy")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item''s current reordering policy.';
                }
                field("Recommended Policy"; Rec."Recommended Policy")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the reordering policy the advisor recommends.';
                }
                field("Current Safety Stock"; Rec."Current Safety Stock")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the safety stock currently on the item.';
                }
                field("Proposed Safety Stock"; Rec."Proposed Safety Stock")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the calculated safety stock proposal.';
                }
                field("Current Reorder Point"; Rec."Current Reorder Point")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the reorder point currently on the item.';
                }
                field("Proposed Reorder Point"; Rec."Proposed Reorder Point")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the calculated reorder point proposal.';
                }
                field("Current Reorder Quantity"; Rec."Current Reorder Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the reorder quantity currently on the item.';
                }
                field("Proposed EOQ"; Rec."Proposed EOQ")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the calculated economic order quantity proposal.';
                }
                field("Current Maximum Inventory"; Rec."Current Maximum Inventory")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the maximum inventory currently on the item.';
                }
                field("Proposed Maximum Inventory"; Rec."Proposed Maximum Inventory")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the proposed order-up-to level (reorder point + EOQ) for items on the Maximum Qty. policy.';
                }
                field("SS Result Code"; Rec."SS Result Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the safety stock calculation outcome.';
                }
                field("ROP Result Code"; Rec."ROP Result Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the reorder point calculation outcome.';
                }
                field("EOQ Result Code"; Rec."EOQ Result Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the EOQ calculation outcome.';
                }
                field(Note; Rec.Note)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the advisor''s reasoning for this item.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LoadItems)
            {
                ApplicationArea = All;
                Caption = 'Load Items';
                Image = ItemLines;
                ToolTip = 'Choose an item filter and compute a proposal preview for every matching inventory item. Nothing is written to items.';

                trigger OnAction()
                var
                    Item: Record Item;
                    RunAll: Codeunit "GSO Run All";
                    FilterPage: FilterPageBuilder;
                    ItemFilterTxt: Text;
                begin
                    FilterPage.AddRecord(Item.TableCaption(), Item);
                    FilterPage.AddFieldNo(Item.TableCaption(), Item.FieldNo("No."));
                    FilterPage.AddFieldNo(Item.TableCaption(), Item.FieldNo("Item Category Code"));
                    FilterPage.AddFieldNo(Item.TableCaption(), Item.FieldNo("Vendor No."));
                    if not FilterPage.RunModal() then
                        exit;
                    ItemFilterTxt := FilterPage.GetView(Item.TableCaption());
                    Item.SetView(ItemFilterTxt);
                    RunAll.BuildProposals(Rec, Item);
                    if Rec.FindFirst() then;
                    CurrPage.Update(false);
                    ShowVarianceSummary();
                end;
            }
            action(ApplySelected)
            {
                ApplicationArea = All;
                Caption = 'Apply Selected';
                Image = Approve;
                ToolTip = 'Run the calculators with apply for every selected line. Values are recalculated, validated and logged — not copied from the preview.';

                trigger OnAction()
                var
                    TempProposal: Record "GSO Planning Proposal" temporary;
                    RunAll: Codeunit "GSO Run All";
                    ConfirmQst: Label 'Apply calculated planning values to %1 selected item(s)?', Comment = '%1 = number of selected items';
                    AppliedMsg: Label '%1 item(s) updated.', Comment = '%1 = number of items applied';
                    SelectedCount: Integer;
                    AppliedCount: Integer;
                begin
                    TempProposal.Copy(Rec, true);
                    TempProposal.Reset();
                    TempProposal.SetRange(Selected, true);
                    SelectedCount := TempProposal.Count();
                    if SelectedCount = 0 then
                        exit;
                    if not Confirm(ConfirmQst, false, SelectedCount) then
                        exit;
                    AppliedCount := RunAll.ApplySelected(TempProposal);
                    RefreshCurrentValues(TempProposal);
                    CurrPage.Update(false);
                    Message(AppliedMsg, AppliedCount);
                end;
            }
            action(SelectAll)
            {
                ApplicationArea = All;
                Caption = 'Select All';
                Image = AllLines;
                ToolTip = 'Select every loaded line.';

                trigger OnAction()
                begin
                    SetSelection(true);
                end;
            }
            action(ClearSelection)
            {
                ApplicationArea = All;
                Caption = 'Clear Selection';
                Image = CancelAllLines;
                ToolTip = 'Deselect every loaded line.';

                trigger OnAction()
                begin
                    SetSelection(false);
                end;
            }
            action(OpenLog)
            {
                ApplicationArea = All;
                Caption = 'Calculation Log';
                Image = History;
                RunObject = page "GSO Calculation Log";
                ToolTip = 'Open the calculation log.';
            }
            action(OpenSetup)
            {
                ApplicationArea = All;
                Caption = 'Setup';
                Image = Setup;
                RunObject = page "GSO Setup";
                ToolTip = 'Open Inventory Planning Setup.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(LoadItems_Promoted; LoadItems) { }
                actionref(ApplySelected_Promoted; ApplySelected) { }
                actionref(SelectAll_Promoted; SelectAll) { }
            }
        }
    }

    local procedure SetSelection(NewValue: Boolean)
    var
        TempProposal: Record "GSO Planning Proposal" temporary;
    begin
        TempProposal.Copy(Rec, true);
        TempProposal.Reset();
        if TempProposal.FindSet() then
            repeat
                TempProposal.Selected := NewValue;
                TempProposal.Modify();
            until TempProposal.Next() = 0;
        CurrPage.Update(false);
    end;

    /// <summary>
    /// After an apply, re-read the items and refresh the "current" columns on
    /// the applied lines, then deselect them — no full reload needed.
    /// </summary>
    local procedure RefreshCurrentValues(var TempProposal: Record "GSO Planning Proposal" temporary)
    var
        Item: Record Item;
    begin
        // The passed record is filtered to Selected = true, and deselecting
        // removes a line from that set — so drain with FindFirst instead of
        // FindSet/Next, which would skip lines when the filter field changes.
        while TempProposal.FindFirst() do begin
            if Item.Get(TempProposal."Item No.") then begin
                TempProposal."Current Safety Stock" := Item."Safety Stock Quantity";
                TempProposal."Current Reorder Point" := Item."Reorder Point";
                TempProposal."Current Reorder Quantity" := Item."Reorder Quantity";
                TempProposal."Current Maximum Inventory" := Item."Maximum Inventory";
                TempProposal."Current Policy" := CopyStr(Format(Item."Reordering Policy"), 1, MaxStrLen(TempProposal."Current Policy"));
            end;
            TempProposal.Selected := false;
            TempProposal.Modify();
        end;
    end;

    /// <summary>
    /// After a load, tell the planner how many lines change the reorder point
    /// materially, so a large worksheet can be triaged instead of read.
    /// </summary>
    local procedure ShowVarianceSummary()
    var
        TempProposal: Record "GSO Planning Proposal" temporary;
        VarianceMsg: Label '%1 of %2 line(s) change the reorder point by more than 25%.', Comment = '%1 = lines with significant variance, %2 = total lines';
        Total: Integer;
        VarianceCount: Integer;
    begin
        TempProposal.Copy(Rec, true);
        TempProposal.Reset();
        if TempProposal.FindSet() then
            repeat
                Total += 1;
                if HasSignificantVariance(TempProposal) then
                    VarianceCount += 1;
            until TempProposal.Next() = 0;
        if VarianceCount > 0 then
            Message(VarianceMsg, VarianceCount, Total);
    end;

    local procedure HasSignificantVariance(var TempProposal: Record "GSO Planning Proposal" temporary): Boolean
    begin
        if not (TempProposal."ROP Result Code" in [TempProposal."ROP Result Code"::OK, TempProposal."ROP Result Code"::"Cap Applied"]) then
            exit(false);
        if TempProposal."Current Reorder Point" = 0 then
            exit(TempProposal."Proposed Reorder Point" > 0);
        exit(Abs(TempProposal."Proposed Reorder Point" - TempProposal."Current Reorder Point") / TempProposal."Current Reorder Point" > 0.25);
    end;
}
