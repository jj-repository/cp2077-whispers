// Whispers of Night City - the website NETdir://nc.whispers (Browser Extension). Builds only while the page is open.
// Two pages under one header: TODAY ("") = the day's whispers + ask around, STILL OUT THERE ("/open/<page>") = every
// revealed open whisper, newest first, 4 per page. Sized to fit the browser page without scrolling (0.1.2).
// Art: archive\pc\mod\WhispersNC.archive (whispers\gui\whispers.inkatlas: part "banner" = the key art for the header,
// "tile" = the browser home tile, "title" = the title lettering alone). Without the archive: text header, vanilla icon.
import BrowserExtension.DataStructures.*
import BrowserExtension.Classes.*
import BrowserExtension.System.*

public abstract class WNCUI {
  public static func Address() -> String = "NETdir://nc.whispers"
  public static func Width() -> Float = 1900.0
  public static func PerPage() -> Int32 = 4
  public static func Font() -> String = "base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily"
  // noir: cream text, one red accent, light greys (readable on the dark panels)
  public static func Cream() -> HDRColor = new HDRColor(0.96, 0.92, 0.80, 1.0)
  public static func Red() -> HDRColor = new HDRColor(1.15, 0.24, 0.20, 1.0)
  public static func Light() -> HDRColor = new HDRColor(0.82, 0.80, 0.74, 1.0)
  public static func Muted() -> HDRColor = new HDRColor(0.66, 0.64, 0.60, 1.0)
  public static func Panel() -> HDRColor = new HDRColor(0.07, 0.06, 0.06, 0.92)
  public static func Atlas() -> ResRef = r"whispers\\gui\\whispers.inkatlas"
  public static func HasArt() -> Bool = GameInstance.GetResourceDepot().ResourceExists(WNCUI.Atlas())

  public static func Text(content: String, size: Int32, color: HDRColor, bold: Bool) -> ref<inkText> {
    let t = new inkText();
    t.SetText(content);
    t.SetFontFamily(WNCUI.Font());
    t.SetFontStyle(bold ? n"Bold" : n"Regular");
    t.SetFontSize(size);
    t.SetLetterCase(textLetterCase.OriginalCase);
    t.SetTintColor(color);
    t.SetFitToContent(true);
    t.SetInteractive(false);
    return t;
  }

  public static func Center(w: ref<inkWidget>) -> ref<inkWidget> {
    w.SetHAlign(inkEHorizontalAlign.Center);
    return w;
  }

  public static func Card(height: Float, bar: HDRColor) -> ref<inkCanvas> {
    let card = new inkCanvas();
    card.SetSize(new Vector2(WNCUI.Width(), height));
    card.SetHAlign(inkEHorizontalAlign.Center);
    let bg = new inkRectangle();
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetTintColor(WNCUI.Panel());
    bg.Reparent(card);
    let edge = new inkRectangle();
    edge.SetSize(new Vector2(10.0, height));
    edge.SetTintColor(bar);
    edge.Reparent(card);
    return card;
  }

  public static func Place(w: ref<inkWidget>, card: ref<inkCanvas>, x: Float, y: Float) -> Void {
    w.SetMargin(new inkMargin(x, y, 0.0, 0.0));
    w.Reparent(card);
  }

  // right-aligned inside a card (buttons)
  public static func PlaceRight(w: ref<inkWidget>, card: ref<inkCanvas>, right: Float, y: Float) -> Void {
    w.SetAnchor(inkEAnchor.TopRight);
    w.SetAnchorPoint(1.0, 0.0);
    w.SetMargin(new inkMargin(0.0, y, right, 0.0));
    w.Reparent(card);
  }

  public static func Banner(small: Bool) -> ref<inkWidget> {
    if !WNCUI.HasArt() || small { return WNCUI.Text("WHISPERS OF NIGHT CITY", 64, WNCUI.Cream(), true); }
    let img = new inkImage();
    img.SetAtlasResource(WNCUI.Atlas());
    img.SetTexturePart(n"banner");
    img.SetSize(new Vector2(560.0, 315.0));
    img.SetInteractive(false);
    return img;
  }
}

public class WNCSite extends BrowserEventsListener {
  private let m_note: String;
  private let m_page: Int32;   // 0 = today, 1.. = still out there, page n

  public func Init(logic: ref<BrowserGameController>) {
    super.Init(logic);
    this.m_siteData.address = WNCUI.Address();
    this.m_siteData.shortName = "Whispers of NC";
    if WNCUI.HasArt() {
      this.m_siteData.iconAtlasPath = WNCUI.Atlas();
      this.m_siteData.iconTexturePart = n"tile";
    } else {
      this.m_siteData.iconAtlasPath = r"base\\gameplay\\gui\\world\\internet\\templates\\atlases\\icons_atlas.inkatlas";
      this.m_siteData.iconTexturePart = n"PofNC";
    }
  }

  public func GetWebPage(address: String) -> ref<inkCompoundWidget> {
    let s = WNCSystem.Get();
    this.m_page = StrContains(address, "/open") ? Max(1, StringToInt(StrAfterLast(address, "/"), 1)) : 0;
    let wrap = new inkVerticalPanel();
    wrap.SetFitToContent(true);
    wrap.SetAnchor(inkEAnchor.TopCenter);
    wrap.SetAnchorPoint(0.5, 0.0);
    wrap.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
    wrap.SetHAlign(inkEHorizontalAlign.Center);
    wrap.SetChildMargin(new inkMargin(0.0, 6.0, 0.0, 6.0));
    WNCUI.Center(WNCUI.Banner(this.m_page == 0 && WNCCfg.Daily() > 3)).Reparent(wrap);
    if !IsDefined(s) { return this.Finish(wrap); }
    s.EnsureDaily();
    if !s.Started() {
      WNCUI.Center(WNCUI.Text("Nobody on the street knows your name yet. Come back once you've made some noise.", 38, WNCUI.Light(), false)).Reparent(wrap);
      return this.Finish(wrap);
    }
    let open = s.OpenList();
    this.Tabs(wrap, ArraySize(open));
    if NotEquals(this.m_note, "") {
      WNCUI.Center(WNCUI.Text(this.m_note, 34, WNCUI.Red(), true)).Reparent(wrap);
      this.m_note = "";
    }
    if this.m_page == 0 { this.Today(wrap, s); } else { this.Open(wrap, s, open); }
    return this.Finish(wrap);
  }

  private func Finish(wrap: ref<inkVerticalPanel>) -> ref<inkCompoundWidget> {
    let canvas = new inkCanvas();
    canvas.SetAnchor(inkEAnchor.Fill);
    wrap.Reparent(canvas);
    return canvas;
  }

  private func Tabs(wrap: ref<inkVerticalPanel>, open: Int32) -> Void {
    let tabs = new inkHorizontalPanel();
    tabs.SetFitToContent(true);
    tabs.SetHAlign(inkEHorizontalAlign.Center);
    tabs.SetChildMargin(new inkMargin(50.0, 4.0, 50.0, 4.0));
    this.Link("TODAY", 44, n"OnTabToday", this.m_page == 0 ? WNCUI.Red() : WNCUI.Light()).Reparent(tabs);
    this.Link("STILL OUT THERE (" + IntToString(open) + ")", 44, n"OnTabOpen", this.m_page > 0 ? WNCUI.Red() : WNCUI.Light()).Reparent(tabs);
    tabs.Reparent(wrap);
  }

  private func Today(wrap: ref<inkVerticalPanel>, s: ref<WNCSystem>) -> Void {
    let k = 1;
    while k <= WNCCfg.Daily() {
      this.PostCard(s, k).Reparent(wrap);
      k += 1;
    }
    let ask = WNCUI.Card(120.0, WNCUI.Red());
    WNCUI.Place(WNCUI.Text("Want more? Buy someone a drink and they'll talk.", 38, WNCUI.Cream(), false), ask, 36.0, 12.0);
    WNCUI.Place(WNCUI.Text("Every ask costs double. Back to " + WNC.Eddies(WNCCfg.AskStart()) + " " + IntToString(WNCCfg.AskResetSeconds() / 3600) + " h after your first ask.", 32, WNCUI.Light(), false), ask, 36.0, 64.0);
    WNCUI.PlaceRight(this.Link("[ ASK AROUND " + WNC.Eddies(s.AskPrice()) + " ]", 40, n"OnAsk", WNCUI.Red()), ask, 40.0, 36.0);
    ask.Reparent(wrap);
    let done = s.ClosedCount();
    WNCUI.Center(WNCUI.Text("Cases closed: " + IntToString(done) + " / " + IntToString(s.TargetCount())
      + (WNCCfg.Rewards() ? "   -   next payout at " + IntToString((done / 10 + 1) * 10) : ""), 34, WNCUI.Light(), false)).Reparent(wrap);
  }

  private func Open(wrap: ref<inkVerticalPanel>, s: ref<WNCSystem>, open: array<Int32>) -> Void {
    let n = ArraySize(open);
    if n == 0 {
      WNCUI.Center(WNCUI.Text("Nothing open. The street's waiting on you.", 38, WNCUI.Light(), false)).Reparent(wrap);
      return;
    }
    let pages = (n + WNCUI.PerPage() - 1) / WNCUI.PerPage();
    this.m_page = Min(this.m_page, pages);
    let i = (this.m_page - 1) * WNCUI.PerPage();
    let last = Min(n, i + WNCUI.PerPage());
    while i < last {
      this.WhisperCard(s, open[i], "ON YOUR MAP", WNCUI.Cream()).Reparent(wrap);
      i += 1;
    }
    let pager = new inkHorizontalPanel();
    pager.SetFitToContent(true);
    pager.SetHAlign(inkEHorizontalAlign.Center);
    pager.SetChildMargin(new inkMargin(40.0, 4.0, 40.0, 4.0));
    this.Link("< NEWER", 40, n"OnNewer", this.m_page > 1 ? WNCUI.Red() : WNCUI.Muted()).Reparent(pager);
    WNCUI.Text("PAGE " + IntToString(this.m_page) + " / " + IntToString(pages), 40, WNCUI.Light(), true).Reparent(pager);
    this.Link("OLDER >", 40, n"OnOlder", this.m_page < pages ? WNCUI.Red() : WNCUI.Muted()).Reparent(pager);
    pager.Reparent(wrap);
  }

  // one whisper: the rumour line, then place + state
  private func WhisperCard(s: ref<WNCSystem>, id: Int32, state: String, bar: HDRColor) -> ref<inkCanvas> {
    let card = WNCUI.Card(120.0, bar);
    WNCUI.Place(WNCUI.Text("\"" + s.Line(id) + "\"", 38, WNCUI.Cream(), false), card, 36.0, 12.0);
    WNCUI.Place(WNCUI.Text(s.Loc(id) + "   [" + state + "]", 32, WNCUI.Light(), false), card, 36.0, 64.0);
    return card;
  }

  private func PostCard(s: ref<WNCSystem>, k: Int32) -> ref<inkCanvas> {
    let ks = IntToString(k);
    let id = WNC.F("wnc_post" + ks);
    if id > 0 && WNC.F("wnc_lk" + ks) == 0 {
      return this.WhisperCard(s, id, s.Done(id) ? "CLOSED" : (s.Gone(id) ? "GONE COLD" : "ON YOUR MAP"), WNCUI.Cream());
    }
    let card = WNCUI.Card(120.0, WNCUI.Red());
    if id <= 0 {
      WNCUI.Place(WNCUI.Text("Quiet day. Nothing new on the street.", 38, WNCUI.Light(), false), card, 36.0, 36.0);
    } else {
      WNCUI.Place(WNCUI.Text("Someone's whispering, but not for free.", 38, WNCUI.Cream(), false), card, 36.0, 12.0);
      WNCUI.Place(WNCUI.Text("Pay the tip and it goes on your map.", 32, WNCUI.Light(), false), card, 36.0, 64.0);
      WNCUI.PlaceRight(this.Link("[ TIP " + WNC.Eddies(s.PostPrice(k)) + " ]", 40, StringToName("OnUnlock" + ks), WNCUI.Red()), card, 40.0, 36.0);
    }
    return card;
  }

  private func Link(label: String, size: Int32, callbackName: CName, color: HDRColor) -> ref<inkText> {
    let link = WNCUI.Text(label, size, color, true);
    link.SetInteractive(true);
    link.SetOpacity(0.85);
    link.RegisterToCallback(n"OnRelease", this, callbackName);
    link.RegisterToCallback(n"OnHoverOver", this, n"OnLinkHoverOver");
    link.RegisterToCallback(n"OnHoverOut", this, n"OnLinkHoverOut");
    return link;
  }

  protected cb func OnLinkHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let target = evt.GetCurrentTarget();
    if IsDefined(target) { target.SetOpacity(1.0); }
  }

  protected cb func OnLinkHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let target = evt.GetCurrentTarget();
    if IsDefined(target) { target.SetOpacity(0.85); }
  }

  private func Go(path: String) -> Void { this.m_deviceLogicController.LoadPageByAddress(WNCUI.Address() + path); }

  private func Act(evt: ref<inkPointerEvent>, k: Int32) -> Void {
    if !evt.IsAction(n"click") { return; }
    let s = WNCSystem.Get();
    if !IsDefined(s) { return; }
    this.m_note = k == 0 ? s.Ask() : s.UnlockPost(k);
    this.Go("");
  }

  protected cb func OnTabToday(evt: ref<inkPointerEvent>) -> Bool { if evt.IsAction(n"click") { this.Go(""); } }
  protected cb func OnTabOpen(evt: ref<inkPointerEvent>) -> Bool { if evt.IsAction(n"click") { this.Go("/open/1"); } }
  protected cb func OnNewer(evt: ref<inkPointerEvent>) -> Bool { if evt.IsAction(n"click") && this.m_page > 1 { this.Go("/open/" + IntToString(this.m_page - 1)); } }
  protected cb func OnOlder(evt: ref<inkPointerEvent>) -> Bool { if evt.IsAction(n"click") { this.Go("/open/" + IntToString(this.m_page + 1)); } }
  protected cb func OnAsk(evt: ref<inkPointerEvent>) -> Bool { this.Act(evt, 0); }
  protected cb func OnUnlock1(evt: ref<inkPointerEvent>) -> Bool { this.Act(evt, 1); }
  protected cb func OnUnlock2(evt: ref<inkPointerEvent>) -> Bool { this.Act(evt, 2); }
  protected cb func OnUnlock3(evt: ref<inkPointerEvent>) -> Bool { this.Act(evt, 3); }
  protected cb func OnUnlock4(evt: ref<inkPointerEvent>) -> Bool { this.Act(evt, 4); }
  protected cb func OnUnlock5(evt: ref<inkPointerEvent>) -> Bool { this.Act(evt, 5); }
}

@addField(BrowserGameController)
private let m_wncSite: ref<WNCSite>;

@wrapMethod(BrowserGameController)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  this.m_wncSite = new WNCSite();
  this.m_wncSite.Init(this);
}

@wrapMethod(BrowserGameController)
protected cb func OnUninitialize() -> Bool {
  wrappedMethod();
  if IsDefined(this.m_wncSite) { this.m_wncSite.Uninit(); this.m_wncSite = null; }
}
