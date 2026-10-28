namespace GMSoft.InventoryPlanning;

using Microsoft.Inventory.Item;

/// <summary>
/// Unified audit log for all four calculators. One row per calculation attempt,
/// including skips, so a bulk run is honest about its coverage. Fields that do
/// not apply to a calculation type are left at their default value.
/// </summary>
table 73030576 "GSO Calculation Log"
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
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
        }
        field(4; "Calculation DateTime"; DateTime)
        {
            Caption = 'Calculation Date/Time';
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
            DecimalPlaces = 0 : 5;
        }
        field(11; "Demand Std Dev"; Decimal)
        {
            Caption = 'Demand Std. Deviation';
            DecimalPlaces = 0 : 5;
        }
        field(12; "Demand Observations"; Integer)
        {
            Caption = 'Demand Observations';
        }
        field(13; "Avg Demand Interval (ADI)"; Decimal)
        {
            Caption = 'Avg. Demand Interval (ADI)';
            DecimalPlaces = 0 : 2;
        }
        field(14; "Demand CV Squared"; Decimal)
        {
            Caption = 'Demand CV²';
            DecimalPlaces = 0 : 4;
        }
        field(15; "Demand Pattern"; Text[30])
        {
            Caption = 'Demand Pattern';
        }
        // ---- Lead time ----
        field(20; "Lead Time (Days)"; Decimal)
        {
            Caption = 'Lead Time (Days)';
            DecimalPlaces = 0 : 2;
        }
        field(21; "Lead Time Std Dev"; Decimal)
        {
            Caption = 'Lead Time Std. Deviation';
            DecimalPlaces = 0 : 2;
        }
        field(22; "Lead Time Source"; Text[50])
        {
            Caption = 'Lead Time Source';
        }
        // ---- Safety stock specifics ----
        field(30; "Service Level %"; Decimal)
        {
            Caption = 'Service Level %';
            DecimalPlaces = 0 : 2;
        }
        field(31; "Z Score"; Decimal)
        {
            Caption = 'Z-Score';
            DecimalPlaces = 0 : 4;
        }
        // ---- EOQ specifics ----
        field(40; "Annual Demand"; Decimal)
        {
            Caption = 'Annual Demand';
            DecimalPlaces = 0 : 2;
        }
        field(41; "Unit Cost"; Decimal)
        {
            Caption = 'Unit Cost';
            DecimalPlaces = 2 : 5;
        }
        field(42; "Holding Cost"; Decimal)
        {
            Caption = 'Holding Cost';
            DecimalPlaces = 2 : 5;
        }
        field(43; "Ordering Cost"; Decimal)
        {
            Caption = 'Ordering Cost';
            DecimalPlaces = 2 : 5;
        }
        // ---- Result ----
        field(50; "Raw Result"; Decimal)
        {
            Caption = 'Raw Result';
            DecimalPlaces = 0 : 5;
        }
        field(51; Result; Decimal)
        {
            Caption = 'Result';
            DecimalPlaces = 0 : 5;
        }
        field(52; "Previous Value"; Decimal)
        {
            Caption = 'Previous Value';
            DecimalPlaces = 0 : 5;
        }
        field(53; Applied; Boolean)
        {
            Caption = 'Applied';
        }
        field(54; "Result Code"; Enum "GSO Result Code")
        {
            Caption = 'Result Code';
        }
        field(55; "Recommended Policy"; Enum "GSO Policy Recommendation")
        {
            Caption = 'Recommended Policy';
        }
        field(56; Note; Text[250])
        {
            Caption = 'Note';
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
