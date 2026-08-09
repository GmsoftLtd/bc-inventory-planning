/// <summary>
/// Adds bulk calculation actions and the Planning Worksheet to the Item List.
/// Bulk actions respect the filters currently applied to the list.
/// </summary>
pageextension 50501 "IPL Item List Ext" extends "Item List"
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
                    Caption = 'Calculate All (Filtered Items)';
                    Image = Calculate;
                    ToolTip = 'Run policy advice, safety stock, reorder point and EOQ for every inventory item in the current filter, and apply the results (subject to setup).';

                    trigger OnAction()
                    var
                        Item: Record Item;
                        RunAll: Codeunit "IPL Run All";
                        Telemetry: Codeunit "IPL Telemetry";
                        ConfirmQst: Label 'Calculate and apply planning values for all items in the current filter?';
                        DoneMsg: Label '%1 item(s) processed. See the calculation log for details.', Comment = '%1 = number of items processed';
                        Processed: Integer;
                    begin
                        if not Confirm(ConfirmQst, false) then
                            exit;
                        CurrPage.SetSelectionFilter(Item);
                        Processed := RunAll.RunBulk(Item, true);
                        Telemetry.LogBulkRun('ALL', Processed);
                        Message(DoneMsg, Processed);
                    end;
                }
                action(IPLAdviseBulk)
                {
                    ApplicationArea = All;
                    Caption = 'Advise Policy (Filtered Items)';
                    Image = SuggestItemPrice;
                    ToolTip = 'Classify demand and log a policy recommendation for every inventory item in the current filter. Policies are written only if auto-update is enabled in setup.';

                    trigger OnAction()
                    var
                        Item: Record Item;
                        PolicyAdvisor: Codeunit "IPL Policy Advisor";
                        Telemetry: Codeunit "IPL Telemetry";
                        DoneMsg: Label '%1 item(s) advised. See the calculation log for recommendations.', Comment = '%1 = number of items processed';
                        Processed: Integer;
                    begin
                        CurrPage.SetSelectionFilter(Item);
                        Processed := PolicyAdvisor.AdviseBulk(Item, true);
                        Telemetry.LogBulkRun('ADVISOR', Processed);
                        Message(DoneMsg, Processed);
                    end;
                }
            }
        }
    }
}
