/// <summary>
/// Read-only list of every calculation attempt across all four calculators.
/// </summary>
page 70455001 "GSO Calculation Log"
{
    PageType = List;
    SourceTable = "GSO Calculation Log";
    Caption = 'Inventory Planning Calculation Log';
    ApplicationArea = All;
    UsageCategory = History;
    Editable = false;
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the sequential number of the log entry.';
                }
                field("Calculation Type"; Rec."Calculation Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which calculator produced this entry.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item the calculation ran for.';
                }
                field("Calculation DateTime"; Rec."Calculation DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the calculation ran.';
                }
                field("Result Code"; Rec."Result Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the outcome: OK, or the reason the item was skipped.';
                }
                field(Result; Rec.Result)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the calculated value.';
                }
                field("Previous Value"; Rec."Previous Value")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value on the item before this calculation.';
                }
                field(Applied; Rec.Applied)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the result was written to the item.';
                }
                field("Recommended Policy"; Rec."Recommended Policy")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recommended reordering policy (policy advice entries only).';
                }
                field("Demand Pattern"; Rec."Demand Pattern")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the demand classification: Smooth, Erratic, Intermittent or Lumpy.';
                }
                field("Avg Daily Demand"; Rec."Avg Daily Demand")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the mean daily demand over the history window.';
                }
                field("Demand Observations"; Rec."Demand Observations")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of days with demand in the history window.';
                }
                field("Lead Time (Days)"; Rec."Lead Time (Days)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lead time used, in days.';
                }
                field("Lead Time Source"; Rec."Lead Time Source")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies where the lead time came from: receipt history, the item, or the setup fallback.';
                }
                field("Service Level %"; Rec."Service Level %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the service level used (safety stock entries only).';
                }
                field(Note; Rec.Note)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the explanation of the result — the formula inputs, or why the item was skipped.';
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who ran the calculation.';
                }
            }
        }
    }
}
