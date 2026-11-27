// Whispers of Night City - core.
// The game's hidden gems (194 in the city, 46 in Dogtown with Phantom Liberty) as street rumours:
//  - map pins stay hidden until a gem is REVEALED (fact wnc_r<id> = reveal order) by
//      * the website NETdir://nc.whispers (WNC_Site.reds): a few whispers per game day, some tip-locked, "ask around";
//      * the street: entering a district / stepping out of a vehicle rolls once for the nearest eligible hidden gem
//        within the radius, at most once per 12 game hours (setting).
//  - a gem is CLOSED (fact wnc_d<id> = 1; 3 = gone for good) by
//      * shard gems: the shard's journal entry turning active (journal callback; owned shards are swept on load),
//      * mail gems: opening that mail on a computer (ComputerControllerPS.GetMailWidget),
//      * weapon gems: the game's own "<weapon>_owned" fact (fact listeners),
//      * spot gems (no shard): V at the spot when she picks something up, enters a district, steps out of a vehicle,
//        or when the gem is revealed / the game loads - only while such a gem is revealed and open.
//  - rewards every 10 closed cases and for all of them.
// Event-driven only: no tick, no polling, nothing per frame. Pins are script mappins (not saved), rebuilt on load.
// Soft integration (compiled only when present): JJ Bank (module JJBankSite) and JJ Rewards (module JJRewardsAPI).

public abstract class WNC {
  public static func QS() -> ref<QuestsSystem> = GameInstance.GetQuestsSystem(GetGameInstance())
  public static func F(name: String) -> Int32 = WNC.QS().GetFactStr(name)
  public static func SetF(name: String, v: Int32) -> Void { WNC.QS().SetFactStr(name, v); }
  public static func Day() -> Int32 = GameTime.Days(GameInstance.GetTimeSystem(GetGameInstance()).GetGameTime())
  public static func Now() -> Int32 {
    let t = GameInstance.GetTimeSystem(GetGameInstance()).GetGameTime();
    return GameTime.Days(t) * 86400 + GameTime.Hours(t) * 3600 + GameTime.Minutes(t) * 60;
  }

  public static func Eddies(v: Int32) -> String {
    let s = IntToString(v);
    let n = StrLen(s);
    let out = "";
    let i = 0;
    while i < n {
      if i > 0 && (n - i) % 3 == 0 { out = out + ","; }
      out = out + StrMid(s, i, 1);
      i += 1;
    }
    return out + " eddies";
  }

  public static func Cash() -> Int32 {
    let p = GetPlayer(GetGameInstance());
    return IsDefined(p) ? GameInstance.GetTransactionSystem(GetGameInstance()).GetItemQuantity(p, MarketSystem.Money()) : 0;
  }

  // a price: bank account first (JJ Bank), else cash
  public static func Pay(price: Int32) -> Bool {
    if price <= 0 { return true; }
    if WNC_BankDebit(price) { return true; }
    let p = GetPlayer(GetGameInstance());
    if !IsDefined(p) || WNC.Cash() < price { return false; }
    return GameInstance.GetTransactionSystem(GetGameInstance()).RemoveItem(p, MarketSystem.Money(), price);
  }

  public static func Give(eddies: Int32, items: array<TweakDBID>, counts: array<Int32>) -> Void {
    let p = GetPlayer(GetGameInstance());
    if !IsDefined(p) { return; }
    let ts = GameInstance.GetTransactionSystem(GetGameInstance());
    let i = 0;
    while i < ArraySize(items) {
      ts.GiveItem(p, ItemID.FromTDBID(items[i]), counts[i]);
      i += 1;
    }
    if eddies > 0 && !WNC_BankCredit(eddies) { ts.GiveItem(p, MarketSystem.Money(), eddies); }
  }

  public static func Notify(text: String) -> Void {
    if WNC_BankNotify(text) { return; }
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = 5.0;
    msg.message = text;
    msg.type = SimpleMessageType.Neutral;
    GameInstance.GetBlackboardSystem(GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications)
      .SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(msg), true);
  }
}

// ---- soft integration: JJ Bank (ledger kind 46 'Whispers') / JJ Rewards (milestone gems_all)
@if(ModuleExists("JJBankSite"))
public func WNC_BankDebit(price: Int32) -> Bool = JJBank.IsOpen() && JJBank.Balance() >= price && JJBank.Debit(price, 46)
@if(!ModuleExists("JJBankSite"))
public func WNC_BankDebit(price: Int32) -> Bool = false
@if(ModuleExists("JJBankSite"))
public func WNC_BankCredit(eddies: Int32) -> Bool = JJBank.Credit(eddies, 46)
@if(!ModuleExists("JJBankSite"))
public func WNC_BankCredit(eddies: Int32) -> Bool = false
@if(ModuleExists("JJBankSite"))
public func WNC_BankNotify(text: String) -> Bool { JJBank.Notify(text, false); return true; }
@if(!ModuleExists("JJBankSite"))
public func WNC_BankNotify(text: String) -> Bool = false
// true = JJ Rewards hands out Comrade's Hammer itself
@if(ModuleExists("JJRewardsAPI"))
public func WNC_RewardsAll() -> Bool { JJRewardsSystem.Get(GetGameInstance()).Milestone("gems_all"); return true; }
@if(!ModuleExists("JJRewardsAPI"))
public func WNC_RewardsAll() -> Bool = false
// the author's own earlier private version (JJ Whispers): carry its reveals and paid tiers over, once
@if(ModuleExists("JJBankSite"))
public func WNC_ImportPrivate() -> Void {
  if WNC.F("jj_wh_init") == 0 { return; }
  let i = 1;
  while i <= 194 {
    let r = WNC.F("jj_wh_r" + IntToString(i));
    if r > 0 { WNC.SetF("wnc_r" + IntToString(i), r); }
    i += 1;
  }
  WNC.SetF("wnc_rseq", WNC.F("jj_wh_rseq"));
  let k = 1;
  while k <= 3 {
    WNC.SetF("wnc_post" + IntToString(k), WNC.F("jj_wh_post" + IntToString(k)));
    WNC.SetF("wnc_lk" + IntToString(k), WNC.F("jj_wh_lk" + IntToString(k)));
    k += 1;
  }
  WNC.SetF("wnc_day", WNC.F("jj_wh_day"));
  WNC.SetF("wnc_ptime", WNC.F("jj_wh_ptime"));
  WNC.SetF("wnc_all", WNC.F("jj_wh_all"));
}
@if(!ModuleExists("JJBankSite"))
public func WNC_ImportPrivate() -> Void {}

public class WNCSystem extends ScriptableSystem {
  private let m_x: array<Float>;
  private let m_y: array<Float>;
  private let m_z: array<Float>;
  private let m_r: array<Float>;
  private let m_zr: array<Float>;
  private let m_kind: array<Int32>;
  private let m_key: array<String>;
  private let m_early: array<Int32>;
  private let m_pre: array<String>;
  private let m_line: array<String>;
  private let m_loc: array<String>;
  private let m_pinGem: array<Int32>;
  private let m_pinId: array<NewMappinID>;
  private let m_spots: array<Int32>;       // revealed, open spot gems (the only ones the position check looks at)
  private let m_factIds: array<Uint32>;
  private let m_factNames: array<CName>;

  public static func Get() -> ref<WNCSystem> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"WNCSystem") as WNCSystem;
  }

  private func Load() -> Void {
    if ArraySize(this.m_x) > 0 { return; }
    this.m_x = WNCData.X();
    this.m_y = WNCData.Y();
    this.m_z = WNCData.Z();
    this.m_r = WNCData.R();
    this.m_zr = WNCData.ZR();
    this.m_kind = WNCData.Kind();
    this.m_key = WNCData.Key();
    this.m_early = WNCData.Early();
    this.m_pre = WNCData.Pre();
    this.m_line = WNCData.Line();
    this.m_loc = WNCData.Loc();
  }

  public func Count() -> Int32 { this.Load(); return ArraySize(this.m_x); }
  public func IsDogtown(id: Int32) -> Bool = id >= WNCData.FirstDogtown()
  // Dogtown gems count (and show) when Phantom Liberty is installed and the setting is on
  public func InPlay(id: Int32) -> Bool = !this.IsDogtown(id) || (IsEP1() && WNCCfg.Dogtown())
  public func DogtownOpen() -> Bool = IsEP1() && WNCCfg.Dogtown() && WNC.F("q301_done") == 1
  public func CityOpen() -> Bool = WNC.F("q001_mission0_complete") > 0 // "The Rescue" done (set in q001_mission0.questphase)
  public func Started() -> Bool = this.CityOpen() || this.DogtownOpen()
  public func Done(id: Int32) -> Bool = WNC.F("wnc_d" + IntToString(id)) == 1
  public func Gone(id: Int32) -> Bool = WNC.F("wnc_d" + IntToString(id)) == 3
  public func Closed(id: Int32) -> Bool = WNC.F("wnc_d" + IntToString(id)) != 0
  public func Revealed(id: Int32) -> Bool = WNC.F("wnc_r" + IntToString(id)) > 0
  public func OnMap(id: Int32) -> Bool = this.Revealed(id) && !this.Closed(id) && this.InPlay(id)
  public func Line(id: Int32) -> String { this.Load(); return this.m_line[id - 1]; }
  public func Loc(id: Int32) -> String { this.Load(); return this.m_loc[id - 1]; }

  // ---- lifecycle
  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.Load();
    ArrayClear(this.m_pinGem);
    ArrayClear(this.m_pinId);
    let first = WNC.F("wnc_init") == 0;
    if first { this.Migrate(); }
    let swept = this.Sweep();
    if first {
      WNC.SetF("wnc_tier", this.ClosedCount() / 10); // cases closed before the mod was installed count, but don't pay
      WNC.SetF("wnc_init", 1);
    }
    this.Listen();
    let i = 1;
    while i <= this.Count() {
      if this.OnMap(i) { this.AddPin(i); }
      i += 1;
    }
    this.RebuildSpots();
    FTLog("[WhispersNC] attach: pins " + IntToString(ArraySize(this.m_pinGem)) + ", closed on load " + IntToString(swept)
      + ", spots watched " + IntToString(ArraySize(this.m_spots)) + ", Dogtown " + (IsEP1() ? "yes" : "no"));
    this.CheckSpots();
    this.Payouts();
  }

  // first load with this mod: progress from the community hidden-gem mods (same gem order) and our private version
  private func Migrate() -> Void {
    let i = 1;
    while i <= this.Count() {
      let s = this.IsDogtown(i) ? WNC.F("dark_pt_g" + IntToString(i - WNCData.FirstDogtown() + 2)) : WNC.F("dark_hg_g" + IntToString(i));
      let done = this.IsDogtown(i) ? s == 2 : s >= 10;
      if done { WNC.SetF("wnc_d" + IntToString(i), 1); }
      else if s == 3 { WNC.SetF("wnc_d" + IntToString(i), 3); }
      else if s == 1 { this.Mark(i); } // an open gig there = already told about it
      i += 1;
    }
    WNC_ImportPrivate();
  }

  private func Listen() -> Void {
    let gi = this.GetGameInstance();
    let journal = GameInstance.GetJournalManager(gi);
    journal.UnregisterScriptCallback(this, n"OnWNCJournal");
    journal.RegisterScriptCallback(this, n"OnWNCJournal", gameJournalListenerType.State);
    let qs = GameInstance.GetQuestsSystem(gi);
    let k = 0;
    while k < ArraySize(this.m_factIds) {
      qs.UnregisterListener(this.m_factNames[k], this.m_factIds[k]);
      k += 1;
    }
    ArrayClear(this.m_factIds);
    ArrayClear(this.m_factNames);
    let i = 1;
    while i <= this.Count() {
      if this.m_kind[i - 1] == 2 && !this.Closed(i) && this.InPlay(i) {
        let n = StringToName(this.m_key[i - 1]);
        ArrayPush(this.m_factNames, n);
        ArrayPush(this.m_factIds, qs.RegisterListener(n, this, n"OnWNCFact"));
      }
      i += 1;
    }
  }

  // owned shards / weapons close their gems (the journal only reports changes). One journal query.
  private func Sweep() -> Int32 {
    let titles = this.ShardTitles();
    let n = 0;
    let i = 1;
    while i <= this.Count() {
      let k = this.m_kind[i - 1];
      if !this.Closed(i) && this.InPlay(i)
        && ((k == 0 && ArrayContains(titles, this.m_key[i - 1])) || (k == 2 && WNC.F(this.m_key[i - 1]) > 0)) {
        WNC.SetF("wnc_d" + IntToString(i), 1);
        n += 1;
      }
      i += 1;
    }
    return n;
  }

  private func ShardTitles() -> array<String> {
    let ctx: JournalRequestContext;
    ctx.stateFilter.active = true;
    let groups: array<ref<JournalOnscreensStructuredGroup>>;
    GameInstance.GetJournalManager(this.GetGameInstance()).GetOnscreens(ctx, groups, n"others");
    let titles: array<String>;
    for g in groups {
      for s in g.GetEntries() {
        if IsDefined(s) { ArrayPush(titles, s.GetTitle()); }
      }
    }
    return titles;
  }

  // ---- completion events
  protected cb func OnWNCJournal(hash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
    if !Equals(className, n"gameJournalOnscreen") { return false; }
    let journal = GameInstance.GetJournalManager(this.GetGameInstance());
    let shard = journal.GetEntry(hash) as JournalOnscreen;
    if IsDefined(shard) && Equals(journal.GetEntryState(shard), gameJournalEntryState.Active) {
      this.CloseByKey(0, shard.GetTitle());
    }
    return false;
  }

  protected cb func OnWNCFact(value: Int32) -> Bool {
    if value <= 0 { return false; }
    let i = 1;
    while i <= this.Count() {
      if this.m_kind[i - 1] == 2 && !this.Closed(i) && this.InPlay(i) && WNC.F(this.m_key[i - 1]) > 0 { this.Close(i); }
      i += 1;
    }
    return false;
  }

  public func CloseByKey(kind: Int32, key: String) -> Void {
    this.Load();
    let i = 1;
    while i <= this.Count() {
      if this.m_kind[i - 1] == kind && Equals(this.m_key[i - 1], key) && !this.Closed(i) && this.InPlay(i) { this.Close(i); }
      i += 1;
    }
  }

  // V's position against the revealed spot gems; no-op (one array size check) while none is revealed
  public func CheckSpots() -> Void {
    if ArraySize(this.m_spots) == 0 { return; }
    let p = GetPlayer(this.GetGameInstance());
    if !IsDefined(p) { return; }
    let pos = p.GetWorldPosition();
    for id in this.m_spots {
      let dx = this.m_x[id - 1] - pos.X;
      let dy = this.m_y[id - 1] - pos.Y;
      let r = this.m_r[id - 1];
      if dx * dx + dy * dy <= r * r && AbsF(this.m_z[id - 1] - pos.Z) <= this.m_zr[id - 1] {
        this.Close(id);
        return; // m_spots changed
      }
    }
  }

  private func RebuildSpots() -> Void {
    ArrayClear(this.m_spots);
    let i = 1;
    while i <= this.Count() {
      if this.m_kind[i - 1] == 1 && this.OnMap(i) { ArrayPush(this.m_spots, i); }
      i += 1;
    }
  }

  private func Close(id: Int32) -> Void {
    if this.Closed(id) { return; }
    WNC.SetF("wnc_d" + IntToString(id), 1);
    this.RemovePin(id);
    if this.m_kind[id - 1] == 1 { this.RebuildSpots(); }
    let done = this.ClosedCount();
    WNC.Notify("Whispers of Night City: case closed (" + IntToString(done) + " / " + IntToString(this.TargetCount()) + ")");
    this.Payouts();
  }

  // ---- eligibility
  private func Lost(id: Int32) -> Bool {
    switch id {
      case 18: return WNC.F("kab_08_finished") == 1 && WNC.F("kab_08_hamill_plans_vengeance") == 0;
      case 50: return WNC.F("jpn_01_alex_is_free") == 1;
      case 71: return true; // its shard is no longer placed in the world since 2.0
      case 142: return WNC.F("jpn_01_alex_is_free") == 0 && this.Done(50);
      case 144: return WNC.F("q000_nomad_male") == 1 || WNC.F("q000_nomad_female") == 1 || WNC.F("q000_corpo_male") == 1 || WNC.F("q000_corpo_female") == 1;
      case 237: return WNC.F("sts_ep1_08_katya_killed") == 1;
    }
    return false;
  }

  private func Reserved(id: Int32) -> Bool {
    let k = 1;
    while k <= 5 {
      if WNC.F("wnc_post" + IntToString(k)) == id && WNC.F("wnc_lk" + IntToString(k)) == 1 { return true; }
      k += 1;
    }
    return false;
  }

  public func Eligible(id: Int32) -> Bool {
    if this.Closed(id) || this.Revealed(id) || this.Reserved(id) || !this.InPlay(id) { return false; }
    if this.Lost(id) { WNC.SetF("wnc_d" + IntToString(id), 3); return false; }
    if this.IsDogtown(id) { if !this.DogtownOpen() { return false; } }
    else {
      if !this.CityOpen() { return false; }
      if this.m_early[id - 1] != 1 && WNC.F("q005_done") != 1 { return false; } // Watson first, the rest after The Heist
      if id == 142 && WNC.F("jpn_01_alex_is_free") != 1 { return false; }
    }
    let pre = this.m_pre[id - 1];
    if StrLen(pre) == 0 { return true; }
    let shards: array<String>;
    let haveShards = false;
    for p in StrSplit(pre, ";") {
      let parts = StrSplit(p, " ");
      let what = parts[0];
      let arg = parts[1];
      if Equals(what, "FACT") && WNC.F(arg) <= 0 { return false; }
      if Equals(what, "NOFACT") && WNC.F(arg) != 0 { return false; }
      if Equals(what, "FACTGE") && WNC.F(arg) < StringToInt(parts[2]) { return false; }
      if Equals(what, "AFTER") && !this.Closed(StringToInt(arg)) { return false; }
      if Equals(what, "SHARD") {
        if !haveShards { shards = this.ShardTitles(); haveShards = true; }
        if !ArrayContains(shards, arg) { return false; }
      }
    }
    return true;
  }

  private func PickRandom() -> Int32 {
    let ids: array<Int32>;
    let i = 1;
    while i <= this.Count() {
      if this.Eligible(i) { ArrayPush(ids, i); }
      i += 1;
    }
    return ArraySize(ids) == 0 ? 0 : ids[RandRange(0, ArraySize(ids))];
  }

  // ---- reveal + pins
  private func Mark(id: Int32) -> Void {
    let seq = WNC.F("wnc_rseq") + 1;
    WNC.SetF("wnc_rseq", seq);
    WNC.SetF("wnc_r" + IntToString(id), seq);
  }

  public func Reveal(id: Int32) -> Void {
    if id <= 0 || this.Revealed(id) { return; }
    this.Mark(id);
    this.AddPin(id);
    if this.m_kind[id - 1] == 1 { this.RebuildSpots(); this.CheckSpots(); }
  }

  private func AddPin(id: Int32) -> Void {
    if ArrayContains(this.m_pinGem, id) { return; }
    let data: MappinData;
    data.mappinType = t"Mappins.QuestStaticMappinDefinition"; // its possibleVariants include QuestGiverVariant
    data.variant = gamedataMappinVariant.QuestGiverVariant;
    data.visibleThroughWalls = true;
    data.debugCaption = "WhispersNC|Whispers of Night City|\"" + this.m_line[id - 1] + "\" - " + this.m_loc[id - 1]; // tooltip, see below
    let pos = new Vector4(this.m_x[id - 1], this.m_y[id - 1], this.m_z[id - 1], 1.0);
    ArrayPush(this.m_pinId, GameInstance.GetMappinSystem(this.GetGameInstance()).RegisterMappin(data, pos));
    ArrayPush(this.m_pinGem, id);
  }

  private func RemovePin(id: Int32) -> Void {
    let i = ArrayFindFirst(this.m_pinGem, id);
    if i < 0 { return; }
    GameInstance.GetMappinSystem(this.GetGameInstance()).UnregisterMappin(this.m_pinId[i]);
    ArrayErase(this.m_pinGem, i);
    ArrayErase(this.m_pinId, i);
  }

  // ---- the street (district entered / V stepped out of a vehicle)
  public func Near() -> Void {
    this.CheckSpots();
    let intro = WNCPhone.Get();
    if IsDefined(intro) { intro.Check(); } // one-shot WHISPERS text at level 5 (WNC_Phone.reds)
    if !this.Started() || WNCCfg.NearPct() <= 0 { return; }
    let now = WNC.Now();
    let last = WNC.F("wnc_ptime");
    if last > 0 && now - last < WNCCfg.NearSeconds() { return; }
    let p = GetPlayer(this.GetGameInstance());
    if !IsDefined(p) { return; }
    this.Load();
    let pos = p.GetWorldPosition();
    let best = 0;
    let bd = WNCCfg.NearRadius() * WNCCfg.NearRadius();
    let i = 1;
    while i <= this.Count() {
      let dx = this.m_x[i - 1] - pos.X;
      let dy = this.m_y[i - 1] - pos.Y;
      let d = dx * dx + dy * dy;
      if d < bd && this.Eligible(i) { best = i; bd = d; }
      i += 1;
    }
    if best == 0 { return; }
    WNC.SetF("wnc_ptime", now);
    if RandRange(0, 100) >= WNCCfg.NearPct() { return; }
    this.Reveal(best);
    WNC.Notify("Whispers: something happened near here. Check your map.");
  }

  // ---- website actions
  public func EnsureDaily() -> Void {
    if WNC.F("wnc_day") == WNC.Day() + 1 || !this.Started() { return; }
    WNC.SetF("wnc_day", WNC.Day() + 1);
    let k = 1;
    while k <= 5 {
      let ks = IntToString(k);
      WNC.SetF("wnc_post" + ks, 0);
      WNC.SetF("wnc_lk" + ks, 0);
      WNC.SetF("wnc_pp" + ks, 0);
      if k <= WNCCfg.Daily() {
        let id = this.PickRandom();
        WNC.SetF("wnc_post" + ks, id);
        if id > 0 { WNC.SetF("wnc_lk" + ks, 1); } // 0.1.2: every daily whisper is paid
      }
      k += 1;
    }
  }

  // price of a locked post: rolled once in [min, max], saved (fact wnc_pp<k>); 0.1.1 posts get theirs on first look
  public func PostPrice(k: Int32) -> Int32 {
    let key = "wnc_pp" + IntToString(k);
    let p = WNC.F(key);
    if p <= 0 {
      let lo = WNCCfg.PriceMin();
      p = RandRange(lo, Max(lo, WNCCfg.PriceMax()) + 1);
      p = Max(p, 1);
      WNC.SetF(key, p);
    }
    return p;
  }

  public func UnlockPost(k: Int32) -> String {
    let ks = IntToString(k);
    let id = WNC.F("wnc_post" + ks);
    if id <= 0 || WNC.F("wnc_lk" + ks) == 0 { return ""; }
    let price = this.PostPrice(k);
    if !WNC.Pay(price) { return "Not enough eddies for the tip (" + WNC.Eddies(price) + ")."; }
    WNC.SetF("wnc_lk" + ks, 0);
    this.Reveal(id);
    return "Tip paid. The whisper is on your map.";
  }

  // ask around: start price, doubled per use; the window opens at the first use and resets after N game hours
  public func AskCount() -> Int32 {
    let n = WNC.F("wnc_askn");
    return n > 0 && WNC.Now() - WNC.F("wnc_askt") >= WNCCfg.AskResetSeconds() ? 0 : n;
  }

  public func AskedOut() -> Bool = this.AskCount() >= WNCCfg.AskMax()

  public func AskPrice() -> Int32 {
    let n = this.AskCount();
    let p = WNCCfg.AskStart();
    while n > 0 && p < 100000000 { p *= 2; n -= 1; }
    return p;
  }

  public func Ask() -> String {
    if this.AskedOut() { return "Nobody else is talking today. Try again later."; }
    let id = this.PickRandom();
    if id == 0 { return "Nobody's talking right now. Nothing new on the street."; }
    let price = this.AskPrice();
    if !WNC.Pay(price) { return "Not enough eddies for the tip (" + WNC.Eddies(price) + ")."; }
    let n = this.AskCount();
    if n == 0 { WNC.SetF("wnc_askt", WNC.Now()); }
    WNC.SetF("wnc_askn", n + 1);
    this.Reveal(id);
    return "\"" + this.Line(id) + "\" - " + this.Loc(id) + "  (on your map)";
  }

  // revealed + open gems, newest first
  public func OpenList() -> array<Int32> {
    let ids: array<Int32>;
    let seqs: array<Int32>;
    let i = 1;
    while i <= this.Count() {
      if this.OnMap(i) {
        let q = WNC.F("wnc_r" + IntToString(i));
        let at = 0; // insertion sort, newest first (a few dozen entries at most)
        while at < ArraySize(seqs) && seqs[at] > q { at += 1; }
        ArrayInsert(ids, at, i);
        ArrayInsert(seqs, at, q);
      }
      i += 1;
    }
    return ids;
  }

  // ---- counts + rewards
  public func ClosedCount() -> Int32 {
    let n = 0;
    let i = 1;
    while i <= this.Count() {
      if this.Done(i) && this.InPlay(i) { n += 1; }
      i += 1;
    }
    return n;
  }

  // cases that can still be closed or are: in play, not gone for good
  public func TargetCount() -> Int32 {
    let n = 0;
    let i = 1;
    while i <= this.Count() {
      if this.InPlay(i) {
        if !this.Closed(i) && this.Lost(i) { WNC.SetF("wnc_d" + IntToString(i), 3); }
        if !this.Gone(i) { n += 1; }
      }
      i += 1;
    }
    return n;
  }

  private func Payouts() -> Void {
    let done = this.ClosedCount();
    let tier = WNC.F("wnc_tier");
    while tier < done / 10 {
      tier += 1;
      WNC.SetF("wnc_tier", tier);
      if WNCCfg.Rewards() {
        WNC.Give(WNCCfg.TierPay(), [t"Items.CommonMaterial1", t"Items.UncommonMaterial1", t"Items.RareMaterial1", t"Items.EpicMaterial1"], [30, 15, 6, 1]);
        WNC.Notify("Whispers of Night City: " + IntToString(tier * 10) + " cases closed - crafting components + " + WNC.Eddies(WNCCfg.TierPay()));
      }
    }
    if done > 0 && WNC.F("wnc_all") == 0 && done >= this.TargetCount() {
      WNC.SetF("wnc_all", 1);
      if WNCCfg.Rewards() {
        WNC.Give(WNCCfg.AllPay(), [t"Items.EpicMaterial1", t"Items.LegendaryMaterial1"], [10, 5]);
        if !WNC_RewardsAll() { WNC.Give(0, [t"Items.Preset_Burya_Comrade_Legendary"], [1]); }
        WNC.Notify("Whispers of Night City: every whisper chased down. " + WNC.Eddies(WNCCfg.AllPay()) + ", legendary components and Comrade's Hammer.");
      }
    }
  }
}

// ---- triggers (event-driven, no polling)
@wrapMethod(PreventionSystem)
private final func OnDistrictAreaEntered(request: ref<DistrictEnteredEvent>) -> Void {
  wrappedMethod(request);
  let s = WNCSystem.Get();
  if IsDefined(s) { s.Near(); }
}

@wrapMethod(VehicleComponent)
protected cb func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Bool {
  let r = wrappedMethod(evt);
  let player = GetPlayer(this.GetVehicle().GetGame());
  if IsDefined(player) && Equals(evt.request.lowLevelMountingInfo.childId, player.GetEntityID()) {
    let s = WNCSystem.Get();
    if IsDefined(s) { s.Near(); }
  }
  return r;
}

// V picked something up: the spot check (an array size test while no spot gem is revealed)
@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
  let r = wrappedMethod(evt);
  let s = WNCSystem.Get();
  if IsDefined(s) { s.CheckSpots(); }
  return r;
}

// a mail opened on a computer
@wrapMethod(ComputerControllerPS)
public final func GetMailWidget(documentAdress: SDocumentAdress) -> SDocumentWidgetPackage {
  let w = wrappedMethod(documentAdress);
  if w.isValid && StrBeginsWith(w.title, "LocKey#") {
    let s = WNCSystem.Get();
    if IsDefined(s) { s.CloseByKey(3, w.title); }
  }
  return w;
}

// pin icon: the game's own shard icon (part "shard" of base\gameplay\gui\common\icons\mappin_icons.inkatlas, the atlas
// every quest / gig pin icon comes from) instead of the quest-giver icon. Our pins are found by their caption; the
// mappin type / variant stay QuestStaticMappinDefinition + QuestGiverVariant (a variant the type allows).
public func WNC_IsOurPin(m: wref<IMappin>) -> Bool = IsDefined(m) && StrBeginsWith(m.GetDisplayName(), "WhispersNC|")

@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  if WNC_IsOurPin(this.m_mappin) { inkImageRef.SetTexturePart(this.iconWidget, n"shard"); }
}

@wrapMethod(MinimapQuestMappinController)
protected final func UpdateIcon() -> Void {
  wrappedMethod();
  if WNC_IsOurPin(this.m_questMappin) { inkImageRef.SetTexturePart(this.iconWidget, n"shard"); }
}

@wrapMethod(MinimapPOIMappinController)
protected final func UpdateIcon() -> Void {
  wrappedMethod();
  if WNC_IsOurPin(this.m_mappin) { inkImageRef.SetTexturePart(this.iconWidget, n"shard"); }
}

@wrapMethod(QuestMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  if WNC_IsOurPin(this.m_mappin) { inkImageRef.SetTexturePart(this.iconWidget, n"shard"); }
}

// pin colour: blue (state RemoteControlDriving = MainColors.ActiveBlue, as Fight Night's ring pins / Boosted's job pin)
// on the world map, minimap (MinimapQuestMappinController inherits MinimapPOI's) and in the world
@wrapMethod(BaseWorldMapMappinController)
protected func ComputeRootState() -> CName {
  return WNC_IsOurPin(this.m_mappin) ? n"RemoteControlDriving" : wrappedMethod();
}

@wrapMethod(MinimapPOIMappinController)
protected func ComputeRootState() -> CName {
  return WNC_IsOurPin(this.m_mappin) ? n"RemoteControlDriving" : wrappedMethod();
}

@wrapMethod(QuestMappinController)
private func ComputeRootState() -> CName {
  return WNC_IsOurPin(this.m_mappin) ? n"RemoteControlDriving" : wrappedMethod();
}

// world map tooltip of our pins: "WhispersNC|<title>|<text>" in the pin's caption
@wrapMethod(WorldMapTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
  wrappedMethod(data, menu);
  let mappin = Deref(data).mappin;
  if !IsDefined(mappin) { return; }
  let name = mappin.GetDisplayName();
  if !StrBeginsWith(name, "WhispersNC|") { return; }
  let parts = StrSplit(name, "|");
  if ArraySize(parts) >= 3 && Equals(GetLocalizedText("UI-MappinTypes-QuestGiver"), inkTextRef.GetText(this.m_titleText)) {
    inkTextRef.SetText(this.m_titleText, parts[1]);
    inkTextRef.SetText(this.m_descText, parts[2]);
  }
}
