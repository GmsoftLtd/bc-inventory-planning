/// <summary>
/// Unified audit log for all four calculators. One row per calculation attempt,
/// including skips, so a bulk run is honest about its coverage. Fields that do
/// not apply to a calculation type are left at their default value.
/// </summary>
table 70455001 "GSO Calculation Log"
{
    Caption = 'Inventory Planning Calculation Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(2; "Calculation Type"; Enum "GSO Calculation Type")
        {
            Caption = 'Calculation Type';
            DataClassification = CustomerContent;
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item;
        }
        field(4; "Calculation DateTime"; DateTime)
        {
            Caption = 'Calculation Date/Time';
            DataClassification = CustomerContent;
        }
        field(5; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        // ---- Demand statistics ----
        field(10; "Avg Daily Demand"; Decimal)
        {
            Caption = 'Avg. Daily Demand';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(11; "Demand Std Dev"; Decimal)
        {
            Caption = 'Demand Std. Deviation';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(12; "Demand Observations"; Integer)
        {
            Caption = 'Demand Observations';
            DataClassification = CustomerContent;
        }
        field(13; "Avg Demand Interval (ADI)"; Decimal)
        {
            Caption = 'Avg. Demand Interval (ADI)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
        }
        field(14; "Demand CV Squared"; Decimal)
        {
            Caption = 'Demand CV²';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
        }
        field(15; "Demand Pattern"; Text[30])
        {
            Caption = 'Demand Pattern';
            DataClassification = CustomerContent;
        }
        // ---- Lead time ----
        field(20; "Lead Time (Days)"; Decimal)
        {
            Caption = 'Lead Time (Days)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
        }
        field(21; "Lead Time Std Dev"; Decimal)
        {
            Caption = 'Lead Time Std. Deviation';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
        }
        field(22; "Lead Time Source"; Text[50])
        {
            Caption = 'Lead Time Source';
            DataClassification = CustomerContent;
        }
        // ---- Safety stock specifics ----
        field(30; "Service Level %"; Decimal)
        {
            Caption = 'Service Level %';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
        }
        field(31; "Z Score"; Decimal)
        {
            Caption = 'Z-Score';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
        }
        // ---- EOQ specifics ----
        field(40; "Annual Demand"; Decimal)
        {
            Caption = 'Annual Demand';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
        }
        field(41; "Unit Cost"; Decimal)
        {
            Caption = 'Unit Cost';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        field(42; "Holding Cost"; Decimal)
        {
            Caption = 'Holding Cost';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        field(43; "Ordering Cost"; Decimal)
        {
            Caption = 'Ordering Cost';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        // ---- Result ----
        field(50; "Raw Result"; Decimal)
        {
            Caption = 'Raw Result';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(51; Result; Decimal)
        {
            Caption = 'Result';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(52; "Previous Value"; Decimal)
        {
            Caption = 'Previous Value';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(53; Applied; Boolean)
        {
            Caption = 'Applied';
            DataClassification = CustomerContent;
        }
        field(54; "Result Code"; Enum "GSO Result Code")
        {
            Caption = 'Result Code';
            DataClassification = CustomerContent;
        }
        field(55; "Recommended Policy"; Enum "GSO Policy Recommendation")
        {
            Caption = 'Recommended Policy';
            DataClassification = CustomerContent;
        }
        field(56; Note; Text[250])
        {
            Caption = 'Note';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ItemType; "Item No.", "Calculation Type", "Calculation DateTime")
        {
        }
    }
}
