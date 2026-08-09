/// <summary>
/// The consolidation feature none of the standalone apps had: current vs
/// proposed planning values for a set of items, side by side, with selective
/// apply. Loading computes previews only; nothing is written until Apply, and
/// applies run through the calculators' validated, logged path.
/// </summary>
page 50502 "IPL Planning Worksheet"
{
    PageType = Worksheet;
    SourceTable = "IPL Planning Proposal";
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
                    RunAll: Codeunit "IPL Run All";
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
                    RunAll: Codeunit "IPL Run All";
                    ConfirmQst: Label 'Apply calculated planning values to %1 selected item(s)?', Comment = '%1 = number of selected items';
                    AppliedMsg: Label '%1 item(s) updated. Reload to see the new current values.', Comment = '%1 = number of items applied';
                    SelectedCount: Integer;
                    TempProposal: Record "IPL Planning Proposal" temporary;
                begin
                    TempProposal.Copy(Rec, true);
                    TempProposal.Reset();
                    TempProposal.SetRange(Selected, true);
                    SelectedCount := TempProposal.Count();
                    if SelectedCount = 0 then
                        exit;
                    if not Confirm(ConfirmQst, false, SelectedCount) then
                        exit;
                    Message(AppliedMsg, RunAll.ApplySelected(TempProposal));
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
                RunObject = page "IPL Calculation Log";
                ToolTip = 'Open the calculation log.';
            }
            action(OpenSetup)
            {
                ApplicationArea = All;
                Caption = 'Setup';
                Image = Setup;
                RunObject = page "IPL Setup";
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
        TempProposal: Record "IPL Planning Proposal" temporary;
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
}
