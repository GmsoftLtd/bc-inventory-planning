/// <summary>
/// Supplies calculated planning parameters to the standard planning engine at
/// planning time, via the Planning-Get Parameters integration events — so the
/// values the engine consumes are computed from live history for that run, not
/// whatever a batch job last wrote to the item.
///
/// Design notes:
/// - Subscribes to OnAtSKUOnAfterCopyFromItem on codeunit 99000855
///   "Planning-Get Parameters" (verified against BC 28 symbols), which passes
///   the Stockkeeping Unit buffer the planning run consumes.
/// - Real Stockkeeping Units are never touched: if a SKU record exists for the
///   item/location/variant, its per-location parameters stand. The provider
///   only fills the buffer that planning copied from the item card — the same
///   values batch mode would have written there.
/// - SingleInstance with a per-run cache: the event fires once per planned
///   item/SKU, and a cold ILE aggregation per call would make a large planning
///   run crawl. The cache invalidates after 5 minutes.
/// - Fails open: if the item can't be calculated (insufficient data, blocked,
///   excluded, make-to-order), the stored values are left untouched.
/// - Never touches order modifiers (Minimum/Maximum Order Qty, Order Multiple):
///   the engine applies those after this point and stays authoritative.
/// - Every fresh computation is written to the calculation log (subject to the
///   Log History setting) as a Dynamic Supply entry, so a planner can always
///   trace where a requisition line's parameters came from, and emits
///   telemetry event GSO0003.
/// - Statistics are item-level (consistent with batch mode).
/// </summary>
codeunit 73030592 "GSO Planning Provider"
{
    SingleInstance = true;
    Permissions = tabledata Item = r,
                  tabledata "Stockkeeping Unit" = r,
                  tabledata "GSO Setup" = ri,
                  tabledata "GSO Calculation Log" = ri;

    var
        CachedSS: Dictionary of [Code[20], Decimal];
        CachedROP: Dictionary of [Code[20], Decimal];
        CachedRQ: Dictionary of [Code[20], Decimal];
        CachedMiss: List of [Code[20]];
        CacheCreatedAt: DateTime;
        CacheTTLMinutes: Integer;
        DynamicSupplyLbl: Label 'Supplied at planning time: SS=%1, ROP=%2, RQ=%3.', Comment = '%1 = safety stock, %2 = reorder point, %3 = reorder quantity (0 = not supplied)';

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Planning-Get Parameters", 'OnAtSKUOnAfterCopyFromItem', '', false, false)]
    local procedure SupplyCalculatedParametersOnAtSKU(var GlobalSKU: Record "Stockkeeping Unit"; var Item: Record Item; ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10])
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
        SafetyStock: Decimal;
        ReorderPoint: Decimal;
        ReorderQty: Decimal;
    begin
        // A real SKU carries deliberate per-location parameters; leave it alone.
        if StockkeepingUnit.Get(LocationCode, ItemNo, VariantCode) then
            exit;

        if not TryGetPlanningValues(ItemNo, SafetyStock, ReorderPoint, ReorderQty) then
            exit; // fail open — stored values stand

        GlobalSKU."Safety Stock Quantity" := SafetyStock;
        GlobalSKU."Reorder Point" := ReorderPoint;
        if ReorderQty > 0 then
            GlobalSKU."Reorder Quantity" := ReorderQty;
    end;

    /// <summary>
    /// Computes (or serves from cache) the planning values for an item. Public
    /// so tests can exercise the exact path the subscriber uses. Returns false
    /// when the provider is disabled or the item cannot be calculated.
    /// </summary>
    procedure TryGetPlanningValues(ItemNo: Code[20]; var SafetyStock: Decimal; var ReorderPoint: Decimal; var ReorderQty: Decimal): Boolean
    var
        Setup: Record "GSO Setup";
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        EOQCalc: Codeunit "GSO EOQ";
        DemandStats: Codeunit "GSO Demand Statistics";
        Telemetry: Codeunit "GSO Telemetry";
        SSCode: Enum "GSO Result Code";
        ROPCode: Enum "GSO Result Code";
        EOQCode: Enum "GSO Result Code";
        Note: Text[250];
        EOQQty: Decimal;
    begin
        Setup.GetSetup();
        if not Setup."Dynamic Provider Enabled" then
            exit(false);

        EnsureCacheFresh();

        if CachedMiss.Contains(ItemNo) then
            exit(false);
        if CachedSS.ContainsKey(ItemNo) then begin
            SafetyStock := CachedSS.Get(ItemNo);
            ReorderPoint := CachedROP.Get(ItemNo);
            ReorderQty := CachedRQ.Get(ItemNo);
            exit(true);
        end;

        if not Item.Get(ItemNo) then
            exit(RememberMiss(ItemNo));
        if Item.Blocked or (Item.Type <> Item.Type::Inventory) then
            exit(RememberMiss(ItemNo));
        if Item."GSO Exclude From Planning" then
            exit(RememberMiss(ItemNo));
        if Setup."Skip Make-to-Order" and DemandStats.IsMakeToOrder(Item) then
            exit(RememberMiss(ItemNo));

        SafetyStock := SafetyStockCalc.CalculatePreview(ItemNo, SSCode, Note);
        if not (SSCode in [SSCode::OK, SSCode::"Cap Applied"]) then
            exit(RememberMiss(ItemNo));

        ReorderPoint := ReorderPointCalc.CalculatePreview(ItemNo, ROPCode, Note);
        if not (ROPCode in [ROPCode::OK, ROPCode::"Cap Applied"]) then
            exit(RememberMiss(ItemNo));

        // EOQ is optional: only meaningful when it writes Reorder Quantity.
        ReorderQty := 0;
        if Setup."EOQ Write Target" = Setup."EOQ Write Target"::"Reorder Quantity" then
            if EOQCalc.CalculatePreview(Item, EOQCode, EOQQty) then
                ReorderQty := EOQQty;

        CachedSS.Set(ItemNo, SafetyStock);
        CachedROP.Set(ItemNo, ReorderPoint);
        CachedRQ.Set(ItemNo, ReorderQty);

        LogDynamicSupply(Setup, ItemNo, SafetyStock, ReorderPoint, ReorderQty);
        Telemetry.LogDynamicSupply();
        exit(true);
    end;

    /// <summary>
    /// Clears the per-run cache. Call after posting demand or changing setup if
    /// a planning run follows within the cache TTL.
    /// </summary>
    procedure ClearCache()
    begin
        Clear(CachedSS);
        Clear(CachedROP);
        Clear(CachedRQ);
        Clear(CachedMiss);
        CacheCreatedAt := CurrentDateTime();
    end;

    local procedure EnsureCacheFresh()
    begin
        if CacheTTLMinutes = 0 then
            CacheTTLMinutes := 5;
        if (CacheCreatedAt = 0DT) or (CurrentDateTime() - CacheCreatedAt > CacheTTLMinutes * 60000) then
            ClearCache();
    end;

    local procedure RememberMiss(ItemNo: Code[20]): Boolean
    begin
        if not CachedMiss.Contains(ItemNo) then
            CachedMiss.Add(ItemNo);
        exit(false);
    end;

    /// <summary>
    /// One audit row per fresh dynamic computation (at most one per item per
    /// cache lifetime), so planning-time values are as traceable as batch ones.
    /// </summary>
    local procedure LogDynamicSupply(Setup: Record "GSO Setup"; ItemNo: Code[20]; SafetyStock: Decimal; ReorderPoint: Decimal; ReorderQty: Decimal)
    var
        LogEntry: Record "GSO Calculation Log";
    begin
        if not Setup."Log History" then
            exit;
        LogEntry.Init();
        LogEntry."Calculation Type" := LogEntry."Calculation Type"::"Dynamic Supply";
        LogEntry."Item No." := ItemNo;
        LogEntry."Calculation DateTime" := CurrentDateTime();
        LogEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."User ID"));
        LogEntry."Raw Result" := SafetyStock;
        LogEntry.Result := ReorderPoint;
        LogEntry.Applied := false;
        LogEntry."Result Code" := LogEntry."Result Code"::OK;
        LogEntry.Note := CopyStr(
            StrSubstNo(DynamicSupplyLbl,
                Format(SafetyStock, 0, 9), Format(ReorderPoint, 0, 9), Format(ReorderQty, 0, 9)),
            1, MaxStrLen(LogEntry.Note));
        LogEntry.Insert(true);
    end;
}
