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
/// - SingleInstance with a per-run cache: the event fires once per planned
///   item/SKU, and a cold ILE aggregation per call would make a large planning
///   run crawl. The cache invalidates after 5 minutes.
/// - Fails open: if the item can't be calculated (insufficient data, blocked,
///   make-to-order), the stored values are left untouched.
/// - Never touches order modifiers (Minimum/Maximum Order Qty, Order Multiple):
///   the engine applies those after this point and stays authoritative.
/// - Statistics are item-level (consistent with batch mode); location/variant
///   granularity is a future enhancement.
/// </summary>
codeunit 50517 "IPL Planning Provider"
{
    SingleInstance = true;

    var
        CachedSS: Dictionary of [Code[20], Decimal];
        CachedROP: Dictionary of [Code[20], Decimal];
        CachedRQ: Dictionary of [Code[20], Decimal];
        CachedMiss: List of [Code[20]];
        CacheCreatedAt: DateTime;
        CacheTTLMinutes: Integer;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Planning-Get Parameters", 'OnAtSKUOnAfterCopyFromItem', '', false, false)]
    local procedure SupplyCalculatedParametersOnAtSKU(var GlobalSKU: Record "Stockkeeping Unit"; var Item: Record Item; ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10])
    var
        SafetyStock: Decimal;
        ReorderPoint: Decimal;
        ReorderQty: Decimal;
    begin
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
        Setup: Record "IPL Setup";
        Item: Record Item;
        SafetyStockCalc: Codeunit "IPL Safety Stock";
        ReorderPointCalc: Codeunit "IPL Reorder Point";
        EOQCalc: Codeunit "IPL EOQ";
        DemandStats: Codeunit "IPL Demand Statistics";
        SSCode: Enum "IPL Result Code";
        ROPCode: Enum "IPL Result Code";
        EOQCode: Enum "IPL Result Code";
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
}
