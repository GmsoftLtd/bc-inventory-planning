/// <summary>
/// Setup card for all four calculators and the dynamic planning provider.
/// </summary>
page 50500 "IPL Setup"
{
    PageType = Card;
    SourceTable = "IPL Setup";
    Caption = 'Inventory Planning Setup';
    ApplicationArea = All;
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("History Window (Days)"; Rec."History Window (Days)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of calendar days of demand history, ending today, that every calculator analyses.';
                }
                field("Min Demand Observations"; Rec."Min Demand Observations")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the minimum number of days with demand required before a calculation is trusted. Items below this are skipped rather than given an unreliable number.';
                }
                field("Round Up Results"; Rec."Round Up Results")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether calculated quantities are rounded up to whole units.';
                }
                field("Skip Make-to-Order"; Rec."Skip Make-to-Order")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether make-to-order items (Make-to-Order manufacturing policy or Order reordering policy) are skipped. Their supply pegs to demand, so stock-level parameters do not apply.';
                }
                field("Default Lead Time (Days)"; Rec."Default Lead Time (Days)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the fallback lead time in days, used when an item has no receipt history and no Lead Time Calculation.';
                }
                field("Log History"; Rec."Log History")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether every calculation attempt, including skips, is written to the calculation log.';
                }
            }
            group(SafetyStock)
            {
                Caption = 'Safety Stock';
                field("Default Service Level %"; Rec."Default Service Level %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the target cycle service level used to derive the Z-score. 95% means accepting a stockout on roughly one replenishment cycle in twenty.';
                }
                field("Apply Safety Stock"; Rec."Apply Safety Stock")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether an applied calculation writes the result to the item''s Safety Stock Quantity field.';
                }
            }
            group(ReorderPoint)
            {
                Caption = 'Reorder Point';
                field("Include Safety Stock"; Rec."Include Safety Stock")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the safety stock quantity is added on top of demand-during-lead-time when calculating the reorder point.';
                }
                field("Apply Reorder Point"; Rec."Apply Reorder Point")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether an applied calculation writes the result to the item''s Reorder Point field.';
                }
                field("Set Policy When None"; Rec."Set Policy When None")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the Reordering Policy is set to Fixed Reorder Qty. when a value is applied to an item that has no policy.';
                }
            }
            group(EOQ)
            {
                Caption = 'EOQ';
                field("Ordering Cost"; Rec."Ordering Cost")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the fixed cost of placing one order (S in the Wilson formula) in local currency.';
                }
                field("Holding Rate"; Rec."Holding Rate")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the annual holding cost as a fraction of unit cost. 0.25 means holding one unit for a year costs 25% of its unit cost.';
                }
                field("Max EOQ Months"; Rec."Max EOQ Months")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a cap on the calculated EOQ, expressed as months of demand, to stop erratic history producing an extreme order quantity.';
                }
                field("EOQ Write Target"; Rec."EOQ Write Target")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which item field an applied EOQ is written to: Reorder Quantity or Order Multiple.';
                }
                field("Cost Source"; Rec."Cost Source")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which item cost field feeds the holding-cost calculation.';
                }
                field("Apply EOQ"; Rec."Apply EOQ")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether an applied calculation writes the result to the configured EOQ target field.';
                }
            }
            group(PolicyAdvisor)
            {
                Caption = 'Policy Advisor';
                field("Lumpy ADI Threshold"; Rec."Lumpy ADI Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Average Demand Interval above which demand counts as intermittent or lumpy (Syntetos-Boylan default 1.32).';
                }
                field("Erratic CV2 Threshold"; Rec."Erratic CV2 Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the squared coefficient of variation above which demand sizes count as erratic or lumpy (Syntetos-Boylan default 0.49).';
                }
                field("Perishable Means Max Qty."; Rec."Perishable Means Max Qty.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether items with an Expiration Calculation are steered to the Maximum Qty. policy so standing stock is capped.';
                }
                field("Auto-Update Policy"; Rec."Auto-Update Policy")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether an applied advice run writes the recommended Reordering Policy to the item. Off by default; recommendations are logged either way.';
                }
            }
            group(Integration)
            {
                Caption = 'Planning Engine Integration';
                field("Dynamic Provider Enabled"; Rec."Dynamic Provider Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether calculated values are supplied directly to the planning engine at planning time via the Planning-Get Parameters events, instead of relying on values stored on the item. Items that cannot be calculated fall back to their stored values.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;
}
