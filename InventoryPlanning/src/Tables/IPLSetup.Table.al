/// <summary>
/// Single-record setup for all four planning calculators, replacing the four
/// separate setup tables of the standalone apps. Defaults follow the standalone
/// apps' defaults so behaviour is unchanged after migration.
/// </summary>
table 50500 "IPL Setup"
{
    Caption = 'Inventory Planning Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        // ---- Shared ----
        field(10; "History Window (Days)"; Integer)
        {
            Caption = 'Demand History Window (Days)';
            DataClassification = CustomerContent;
            MinValue = 30;
            MaxValue = 1095;
            InitValue = 365;
        }
        field(11; "Min Demand Observations"; Integer)
        {
            Caption = 'Min Demand Observations';
            DataClassification = CustomerContent;
            MinValue = 3;
            InitValue = 20;
        }
        field(12; "Round Up Results"; Boolean)
        {
            Caption = 'Round Up Results to Whole Units';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(13; "Log History"; Boolean)
        {
            Caption = 'Log Calculation History';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(14; "Skip Make-to-Order"; Boolean)
        {
            Caption = 'Skip Make-to-Order Items';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(15; "Default Lead Time (Days)"; Integer)
        {
            Caption = 'Fallback Lead Time (Days)';
            DataClassification = CustomerContent;
            MinValue = 0;
            InitValue = 7;
        }
        // ---- Safety Stock ----
        field(20; "Default Service Level %"; Decimal)
        {
            Caption = 'Default Service Level %';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            MinValue = 70;
            MaxValue = 99.99;
            InitValue = 95;
        }
        field(21; "Apply Safety Stock"; Boolean)
        {
            Caption = 'Write Safety Stock to Item';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        // ---- Reorder Point ----
        field(30; "Include Safety Stock"; Boolean)
        {
            Caption = 'Add Safety Stock to Reorder Point';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(31; "Apply Reorder Point"; Boolean)
        {
            Caption = 'Write Reorder Point to Item';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(32; "Set Policy When None"; Boolean)
        {
            Caption = 'Set Policy to Fixed Reorder Qty. when None';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        // ---- EOQ ----
        field(40; "Ordering Cost"; Decimal)
        {
            Caption = 'Ordering Cost (S)';
            DataClassification = CustomerContent;
            MinValue = 0;
            InitValue = 50;
        }
        field(41; "Holding Rate"; Decimal)
        {
            Caption = 'Holding Rate (fraction of unit cost/year)';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 4;
            MinValue = 0;
            MaxValue = 1;
            InitValue = 0.25;
        }
        field(42; "Max EOQ Months"; Decimal)
        {
            Caption = 'Maximum EOQ (Months of Demand)';
            DataClassification = CustomerContent;
            DecimalPlaces = 1 : 2;
            MinValue = 0.5;
            InitValue = 6;
        }
        field(43; "EOQ Write Target"; Enum "IPL EOQ Write Target")
        {
            Caption = 'EOQ Write Target';
            DataClassification = CustomerContent;
        }
        field(44; "Cost Source"; Enum "IPL Cost Source")
        {
            Caption = 'Unit Cost Source';
            DataClassification = CustomerContent;
        }
        field(45; "Apply EOQ"; Boolean)
        {
            Caption = 'Write EOQ to Item';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        // ---- Policy Advisor ----
        field(50; "Lumpy ADI Threshold"; Decimal)
        {
            Caption = 'Intermittent ADI Threshold';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
            MinValue = 1;
            InitValue = 1.32;
        }
        field(51; "Erratic CV2 Threshold"; Decimal)
        {
            Caption = 'Erratic CV-Squared Threshold';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
            MinValue = 0;
            InitValue = 0.49;
        }
        field(52; "Perishable Means Max Qty."; Boolean)
        {
            Caption = 'Treat Shelf Life as Maximum Qty.';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(53; "Auto-Update Policy"; Boolean)
        {
            Caption = 'Auto-Update Item Reordering Policy';
            DataClassification = CustomerContent;
            InitValue = false;
        }
        // ---- Planning Engine Integration ----
        field(60; "Dynamic Provider Enabled"; Boolean)
        {
            Caption = 'Supply Values at Planning Time (Dynamic)';
            DataClassification = CustomerContent;
            InitValue = false;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Gets the singleton setup record, creating it with defaults on first use.
    /// </summary>
    procedure GetSetup()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;
}
