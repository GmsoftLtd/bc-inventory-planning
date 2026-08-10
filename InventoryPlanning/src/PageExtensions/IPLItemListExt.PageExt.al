/// <summary>
/// Adds bulk calculation actions and the Planning Worksheet to the Item List.
/// Bulk actions run on the rows the user selected when more than one row is
/// selected; otherwise they honour the filters applied to the list — matching
/// what the captions promise.
/// </summary>
pageextension 70455001 "IPL Item List Ext" extends "Item List"
{
    actions
    {
        addlast(processing)
        {
            group(IPLPlanning)
            {
                Caption = 'Inventory Planning';
                Image = Planning;

                action(IPLWorksheet)
                {
                    ApplicationArea = All;
                    Caption = 'Planning Worksheet';
                    Image = Worksheet;
                    RunObject = page "IPL Planning Worksheet";
                    ToolTip = 'Open the planning worksheet to preview and selectively apply calculated values for a set of items.';
                }
                action(IPLRunAllBulk)
                {
                    ApplicationArea = All;
                    Caption = 'Calculate All (Selected/Filtered Items)';
                    Image = Calculate;
                    ToolTip = 'Run policy advice, safety stock, reorder point and EOQ for the selected rows, or for every inventory item in the current filter when no multi-selection is made, and apply the results (subject to setup).';

                    trigger OnAction()
                    var
                        Item: Record Item;
                        RunAll: Codeunit "IPL Run All";
                        Telemetry: Codeunit "IPL Telemetry";
                        ConfirmQst: Label 'Calculate and apply planning values for %1 item(s)?', Comment = '%1 = number of items in scope';
                        DoneMsg: Label '%1 item(s) processed. See the calculation log for details.', Comment = '%1 = number of items processed';
                        Processed: Integer;
                    begin
                        GetScope(Item);
                        if not Confirm(ConfirmQst, false, Item.Count()) then
                            exit;
                        Processed := RunAll.RunBulk(Item, true);
                        Telemetry.LogBulkRun('ALL', Processed);
                        Message(DoneMsg, Processed);
                    end;
                }
                action(IPLAdviseBulk)
                {
                    ApplicationArea = All;
                    Caption = 'Advise Policy (Selected/Filtered Items)';
                    Image = SuggestItemPrice;
                    ToolTip = 'Classify demand and log a policy recommendation for the selected rows, or for every inventory item in the current filter when no multi-selection is made. Policies are written only if auto-update is enabled in setup.';

                    trigger OnAction()
                    var
                        Item: Record Item;
                        PolicyAdvisor: Codeunit "IPL Policy Advisor";
                        Telemetry: Codeunit "IPL Telemetry";
                        DoneMsg: Label '%1 item(s) advised. See the calculation log for recommendations.', Comment = '%1 = number of items processed';
                        Processed: Integer;
                    begin
                        GetScope(Item);
                        Processed := PolicyAdvisor.AdviseBulk(Item, true);
                        Telemetry.LogBulkRun('ADVISOR', Processed);
                        Message(DoneMsg, Processed);
                    end;
                }
            }
        }
        addlast(Promoted)
        {
            group(Category_IPL)
            {
                Caption = 'Inventory Planning';
                actionref(IPLWorksheet_Promoted; IPLWorksheet) { }
                actionref(IPLRunAllBulk_Promoted; IPLRunAllBulk) { }
                actionref(IPLAdviseBulk_Promoted; IPLAdviseBulk) { }
            }
        }
    }

    /// <summary>
    /// A deliberate multi-selection wins; otherwise the list's filters define
    /// the scope. SetSelectionFilter alone returns just the cursor row, which
    /// silently ignored the filter the captions promise to honour.
    /// </summary>
    local procedure GetScope(var Item: Record Item)
    begin
        CurrPage.SetSelectionFilter(Item);
        if Item.Count() <= 1 then begin
            Item.Reset();
            Item.CopyFilters(Rec);
        end;
    end;
}
