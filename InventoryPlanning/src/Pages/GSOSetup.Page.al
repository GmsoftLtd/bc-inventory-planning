/// <summary>
/// Setup card for all four calculators and the dynamic planning provider.
/// </summary>
page 70455000 "GSO Setup"
{
    PageType = Card;
    SourceTable = "GSO Setup";
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
                    ToolTip = 'Specifies the number of calendar days of demand history, ending on the work date, that every calculator analyses.';
                }
                field("Min Demand Observations"; Rec."Min Demand Observations")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the minimum number of days with demand required before a calculation is trusted. Items below this are skipped rather than given an unreliable number.';
                }
                field("Include Consumption Demand"; Rec."Include Consumption Demand")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether production and assembly consumption count as demand alongside sales. Enable this in manufacturing companies so purchased components are planned from their real usage.';
                }
                field("Trend Warning Threshold %"; Rec."Trend Warning Threshold %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the deviation between recent demand and the full-window average above which calculations carry a trend warning in their notes, because history-based values lag ramps and phase-outs. 0 disables the warning.';
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
                    ToolTip = 'Specifies whether every calculation attempt, including skips and dynamic planning-time supplies, is written to the calculation log.';
                }
            }
            group(SafetyStock)
            {
                Caption = 'Safety Stock';
                field("Default Service Level %"; Rec."Default Service Level %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the target cycle service level used to derive the Z-score. 95% means accepting a stockout on roughly one replenishment cycle in twenty. Items can override this individually on the item card.';
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
                    ToolTip = 'Specifies whether the Reordering Policy is set to Fixed Reorder Qty. when a value is applied to an item that has no policy. In a Run All, this is suppressed when the policy advisor recommends a different policy.';
                }
                field("Apply Maximum Inventory"; Rec."Apply Maximum Inventory")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether a Run All writes Maximum Inventory (reorder point + EOQ, the order-up-to level) for items on the Maximum Qty. policy, completing the min/max parameter pair.';
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
                    ToolTip = 'Specifies whether calculated values are supplied directly to the planning engine at planning time via the Planning-Get Parameters events, instead of relying on values stored on the item. Items with a Stockkeeping Unit or that cannot be calculated fall back to their stored values.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateJobQueueEntry)
            {
                ApplicationArea = All;
                Caption = 'Create Job Queue Entry';
                Image = Calendar;
                ToolTip = 'Create a recurring Job Queue Entry that runs all calculators nightly. The entry is created on hold so you can review the schedule before setting it to Ready.';

                trigger OnAction()
                var
                    JobQueueEntry: Record "Job Queue Entry";
                begin
                    JobQueueEntry.Init();
                    JobQueueEntry.ID := CreateGuid();
                    JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
                    JobQueueEntry."Object ID to Run" := Codeunit::"GSO Job Queue";
                    JobQueueEntry."Parameter String" := 'ALL';
                    JobQueueEntry.Description := CopyStr(JobQueueDescriptionLbl, 1, MaxStrLen(JobQueueEntry.Description));
                    JobQueueEntry."Recurring Job" := true;
                    JobQueueEntry."Run on Mondays" := true;
                    JobQueueEntry."Run on Tuesdays" := true;
                    JobQueueEntry."Run on Wednesdays" := true;
                    JobQueueEntry."Run on Thursdays" := true;
                    JobQueueEntry."Run on Fridays" := true;
                    JobQueueEntry."Run on Saturdays" := true;
                    JobQueueEntry."Run on Sundays" := true;
                    JobQueueEntry."Starting Time" := 030000T;
                    JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
                    JobQueueEntry.Insert(true);
                    Page.Run(Page::"Job Queue Entry Card", JobQueueEntry);
                end;
            }
            action(OpenWorksheet)
            {
                ApplicationArea = All;
                Caption = 'Planning Worksheet';
                Image = Worksheet;
                RunObject = page "GSO Planning Worksheet";
                ToolTip = 'Open the planning worksheet to preview and selectively apply calculated values.';
            }
            action(OpenLog)
            {
                ApplicationArea = All;
                Caption = 'Calculation Log';
                Image = History;
                RunObject = page "GSO Calculation Log";
                ToolTip = 'Open the calculation log.';
            }
        }
        area(Navigation)
        {
            action(GMSoftSuite)
            {
                ApplicationArea = All;
                Caption = 'About SKU-Level Planning';
                Image = Info;
                ToolTip = 'This free app calculates at item level. Learn about per-location (SKU) planning, ABC service levels and the exception workbench in the GMSoft manufacturing suite.';

                trigger OnAction()
                begin
                    Hyperlink('https://insidebusinesscentral.com/');
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(CreateJobQueueEntry_Promoted; CreateJobQueueEntry) { }
                actionref(OpenWorksheet_Promoted; OpenWorksheet) { }
                actionref(OpenLog_Promoted; OpenLog) { }
            }
        }
    }

    var
        JobQueueDescriptionLbl: Label 'Inventory Planning: recalculate planning parameters';

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;
}
