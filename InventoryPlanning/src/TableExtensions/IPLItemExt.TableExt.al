/// <summary>
/// Per-item planning controls: an exclusion flag so planner-maintained values
/// are never overwritten by a bulk or scheduled run, and an optional per-item
/// service level that overrides the company default (0 = use setup default).
/// </summary>
tableextension 70455000 "IPL Item Ext" extends Item
{
    fields
    {
        field(70455000; "IPL Exclude From Planning"; Boolean)
        {
            Caption = 'Exclude from Inventory Planning';
            DataClassification = CustomerContent;
        }
        field(70455001; "IPL Service Level %"; Decimal)
        {
            Caption = 'Planning Service Level % (0 = default)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 99.99;
        }
    }
}
