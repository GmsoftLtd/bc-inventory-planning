/// <summary>
/// Adds the per-item planning controls to the Planning tab, and the four
/// calculators plus the run-all action to the Item Card.
/// </summary>
pageextension 73030575 "GSO Item Card Ext" extends "Item Card"
{
    layout
    {
        addlast(Planning)
        {
            field("GSO Exclude From Planning"; Rec."GSO Exclude From Planning")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether this item is skipped by all Inventory Planning calculators, so manually maintained planning values are never overwritten.';
            }
            field("GSO Service Level %"; Rec."GSO Service Level %")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies a service level for this item''s safety stock calculation, overriding the default in Inventory Planning Setup. 0 means use the default.';
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            group(GSOPlanning)
            {
                Caption = 'Inventory Planning';
                Image = Planning;

                action(GSORunAll)
                {
                    ApplicationArea = All;
                    Caption = 'Calculate All Planning Values';
                    Image = Calculate;
                    ToolTip = 'Run policy advice, safety stock, reorder point and EOQ for this item in dependency order, and apply the results (subject to setup).';

                    trigger OnAction()
                    var
                        RunAll: Codeunit "GSO Run All";
                        DoneMsg: Label 'Planning values calculated. See the calculation log for details.';
                    begin
                        RunAll.RunForItem(Rec."No.", true);
                        CurrPage.Update(false);
                        Message(DoneMsg);
                    end;
                }
                action(GSOSafetyStock)
                {
                    ApplicationArea = All;
                    Caption = 'Calculate Safety Stock';
                    Image = CalculateInventory;
                    ToolTip = 'Calculate safety stock from demand and lead-time variability and apply it (subject to setup).';

                    trigger OnAction()
                    var
                        SafetyStockCalc: Codeunit "GSO Safety Stock";
                        ResultCode: Enum "GSO Result Code";
                        Note: Text[250];
                        ResultMsg: Label 'Safety stock: %1. %2', Comment = '%1 = calculated value, %2 = explanation';
                        Result: Decimal;
                    begin
                        Result := SafetyStockCalc.CalculateForItem(Rec."No.", 0, true, ResultCode, Note);
                        CurrPage.Update(false);
                        Message(ResultMsg, Result, Note);
                    end;
                }
                action(GSOReorderPoint)
                {
                    ApplicationArea = All;
                    Caption = 'Calculate Reorder Point';
                    Image = CalculateInventory;
                    ToolTip = 'Calculate the reorder point from demand during lead time plus safety stock, and apply it (subject to setup).';

                    trigger OnAction()
                    var
                        ReorderPointCalc: Codeunit "GSO Reorder Point";
                        ResultCode: Enum "GSO Result Code";
                        Note: Text[250];
                        ResultMsg: Label 'Reorder point: %1. %2', Comment = '%1 = calculated value, %2 = explanation';
                        Result: Decimal;
                    begin
                        Result := ReorderPointCalc.CalculateForItem(Rec."No.", true, -1, ResultCode, Note);
                        CurrPage.Update(false);
                        Message(ResultMsg, Result, Note);
                    end;
                }
                action(GSOEOQ)
                {
                    ApplicationArea = All;
                    Caption = 'Calculate EOQ';
                    Image = CalculateInventory;
                    ToolTip = 'Calculate the economic order quantity via the Wilson formula and apply it to the configured target field (subject to setup).';

                    trigger OnAction()
                    var
                        EOQCalc: Codeunit "GSO EOQ";
                        ResultCode: Enum "GSO Result Code";
                        AppliedQty: Decimal;
                        OkMsg: Label 'EOQ: %1.', Comment = '%1 = calculated quantity';
                        SkippedMsg: Label 'EOQ not calculated: %1.', Comment = '%1 = result code';
                    begin
                        if EOQCalc.Calculate(Rec, true, ResultCode, AppliedQty) then
                            Message(OkMsg, AppliedQty)
                        else
                            Message(SkippedMsg, ResultCode);
                        CurrPage.Update(false);
                    end;
                }
                action(GSOAdvisePolicy)
                {
                    ApplicationArea = All;
                    Caption = 'Advise Reordering Policy';
                    Image = SuggestItemPrice;
                    ToolTip = 'Classify this item''s demand pattern and recommend a reordering policy. Writes the policy only if auto-update is enabled in setup.';

                    trigger OnAction()
                    var
                        PolicyAdvisor: Codeunit "GSO Policy Advisor";
                        Recommendation: Enum "GSO Policy Recommendation";
                        Pattern: Text[30];
                        Note: Text[250];
                        AdviceMsg: Label 'Recommended policy: %1 (%2 demand). %3', Comment = '%1 = recommended policy, %2 = demand pattern, %3 = reasoning';
                    begin
                        Recommendation := PolicyAdvisor.AdviseForItem(Rec."No.", true, Pattern, Note);
                        CurrPage.Update(false);
                        Message(AdviceMsg, Recommendation, Pattern, Note);
                    end;
                }
                action(GSOViewLog)
                {
                    ApplicationArea = All;
                    Caption = 'Calculation Log';
                    Image = History;
                    ToolTip = 'Open the calculation log filtered to this item.';

                    trigger OnAction()
                    var
                        LogEntry: Record "GSO Calculation Log";
                        LogPage: Page "GSO Calculation Log";
                    begin
                        LogEntry.SetRange("Item No.", Rec."No.");
                        LogPage.SetTableView(LogEntry);
                        LogPage.Run();
                    end;
                }
            }
        }
    }
}
