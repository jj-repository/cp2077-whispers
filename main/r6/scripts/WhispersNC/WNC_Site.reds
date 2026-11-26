// Whispers of Night City - the website NETdir://nc.whispers (Browser Extension). Builds only while the page is open.
// Art: archive\pc\mod\WhispersNC.archive (whispers\gui\whispers.inkatlas: part "banner" = the key art for the header,
// "tile" = the browser home tile, "title" = the title lettering alone). Without the archive: text header, vanilla icon.
import BrowserExtension.DataStructures.*
import BrowserExtension.Classes.*
import BrowserExtension.System.*

public abstract class WNCUI {
  public static func Address() -> String = "NETdir://nc.whispers"
  public static func Width() -> Float = 1900.0
  public static func Font() -> String = "base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily"
  // noir: cream text, one red accent, greys
  public static func Cream() -> HDRColor = new HDRColor(0.93, 0.88, 0.76, 1.0)
  public static func Red() -> HDRColor = new HDRColor(1.10, 0.20, 0.18, 1.0)
  public static func Muted() -> HDRColor = new HDRColor(0.62, 0.60, 0.56, 1.0)
  public static func Dim() -> HDRColor = new HDRColor(0.38, 0.37, 0.35, 1.0)
  public static func Panel() -> HDRColor = new HDRColor(0.05, 0.045, 0.045, 1.0)
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
    edge.SetSize(new Vector2(8.0, height));
    edge.SetTintColor(bar);
    edge.Reparent(card);
    return card;
  }

  public static func Place(w: ref<inkWidget>, card: ref<inkCanvas>, x: Float, y: Float) -> Void {
    w.SetMargin(new inkMargin(x, y, 0.0, 0.0));
    w.Reparent(card);
  }

  public static func Banner() -> ref<inkWidget> {
    if !WNCUI.HasArt() { return WNCUI.Text("WHISPERS OF NIGHT CITY", 72, WNCUI.Cream(), true); }
    let img = new inkImage();
    img.SetAtlasResource(WNCUI.Atlas());
    img.SetTexturePart(n"banner");
    img.SetSize(new Vector2(960.0, 540.0));
    img.SetInteractive(false);
    return img;
  }
}

public class WNCSite extends BrowserEventsListener {
  private let m_note: String;

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
    let wrap = new inkVerticalPanel();
    wrap.SetFitToContent(true);
    wrap.SetAnchor(inkEAnchor.TopCenter);
    wrap.SetAnchorPoint(0.5, 0.0);
    wrap.SetMargin(new inkMargin(0.0, 30.0, 0.0, 0.0));
    wrap.SetHAlign(inkEHorizontalAlign.Center);
    wrap.SetChildMargin(new inkMargin(0.0, 6.0, 0.0, 6.0));
    WNCUI.Center(WNCUI.Banner()).Reparent(wrap);
    WNCUI.Center(WNCUI.Text("Street talk, overheard and resold. Every whisper marks a spot on your map.", 32, WNCUI.Muted(), false)).Reparent(wrap);
    if !IsDefined(s) { return this.Finish(wrap); }
    s.EnsureDaily();
    if NotEquals(this.m_note, "") {
      WNCUI.Center(WNCUI.Text(this.m_note, 28, WNCUI.Red(), true)).Reparent(wrap);
      this.m_note = "";
    }
    if !s.Started() {
      WNCUI.Center(WNCUI.Text("Nobody on the street knows your name yet. Come back once you've made some noise.", 30, WNCUI.Dim(), false)).Reparent(wrap);
      return this.Finish(wrap);
    }
    this.Section(wrap, "TODAY'S WHISPERS");
    let k = 1;
    while k <= WNCCfg.Daily() {
      this.PostCard(s, k).Reparent(wrap);
      k += 1;
    }
    let ask = WNCUI.Card(90.0, WNCUI.Red());
    WNCUI.Place(WNCUI.Text("Want more? Buy someone a drink and they'll talk.", 28, WNCUI.Muted(), false), ask, 30.0, 25.0);
    WNCUI.Place(this.Link("[ ASK AROUND " + WNC.Eddies(WNCCfg.Ask()) + " ]", 32, n"OnAsk", WNCUI.Cream()), ask, 1420.0, 22.0);
    ask.Reparent(wrap);
    this.Section(wrap, "STILL OUT THERE");
    let shown = 0;
    let below = 2147483647;
    while shown < 6 {
      let best = 0;
      let bseq = 0;
      let i = 1;
      while i <= s.Count() {
        let q = WNC.F("wnc_r" + IntToString(i));
        if q > bseq && q < below && s.OnMap(i) { best = i; bseq = q; }
        i += 1;
      }
      if best == 0 { break; }
      WNCUI.Center(WNCUI.Text("\"" + s.Line(best) + "\" - " + s.Loc(best), 24, WNCUI.Muted(), false)).Reparent(wrap);
      below = bseq;
      shown += 1;
    }
    if shown == 0 { WNCUI.Center(WNCUI.Text("Nothing open. The street's waiting on you.", 24, WNCUI.Dim(), false)).Reparent(wrap); }
    let done = s.ClosedCount();
    WNCUI.Center(WNCUI.Text("Cases closed: " + IntToString(done) + " / " + IntToString(s.TargetCount())
      + (WNCCfg.Rewards() ? ".  Next payout at " + IntToString((done / 10 + 1) * 10) + " (crafting components + " + WNC.Eddies(WNCCfg.TierPay()) + "). Close them all for the big one." : "."),
      24, WNCUI.Dim(), false)).Reparent(wrap);
    WNCUI.Center(WNCUI.Text("Walk the city: get close to something and the street may whisper on its own.", 22, WNCUI.Dim(), false)).Reparent(wrap);
    return this.Finish(wrap);
  }

  private func Finish(wrap: ref<inkVerticalPanel>) -> ref<inkCompoundWidget> {
    let canvas = new inkCanvas();
    canvas.SetAnchor(inkEAnchor.Fill);
    wrap.Reparent(canvas);
    return canvas;
  }

  private func Section(wrap: ref<inkVerticalPanel>, title: String) -> Void {
    let t = WNCUI.Text(title, 32, WNCUI.Red(), true);
    t.SetMargin(new inkMargin(0.0, 14.0, 0.0, 0.0));
    WNCUI.Center(t).Reparent(wrap);
  }

  private func PostCard(s: ref<WNCSystem>, k: Int32) -> ref<inkCanvas> {
    let ks = IntToString(k);
    let id = WNC.F("wnc_post" + ks);
    let locked = id > 0 && WNC.F("wnc_lk" + ks) == 1;
    let card = WNCUI.Card(100.0, locked ? WNCUI.Red() : WNCUI.Cream());
    if id <= 0 {
      WNCUI.Place(WNCUI.Text("Quiet day. Nothing new on the street.", 28, WNCUI.Dim(), false), card, 30.0, 30.0);
    } else if locked {
      WNCUI.Place(WNCUI.Text("Someone's whispering, but not for free.", 28, WNCUI.Muted(), false), card, 30.0, 30.0);
      WNCUI.Place(this.Link("[ TIP " + WNC.Eddies(WNCCfg.Unlock()) + " ]", 32, StringToName("OnUnlock" + ks), WNCUI.Red()), card, 1520.0, 28.0);
    } else {
      let st = s.Done(id) ? "CLOSED" : (s.Gone(id) ? "GONE COLD" : "ON YOUR MAP");
      WNCUI.Place(WNCUI.Text("\"" + s.Line(id) + "\"", 26, WNCUI.Cream(), false), card, 30.0, 8.0);
      WNCUI.Place(WNCUI.Text(s.Loc(id) + "   [" + st + "]", 24, WNCUI.Dim(), false), card, 30.0, 56.0);
    }
    return card;
  }

  private func Link(label: String, size: Int32, callbackName: CName, color: HDRColor) -> ref<inkText> {
    let link = WNCUI.Text(label, size, color, true);
    link.SetInteractive(true);
    link.SetOpacity(0.8);
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
    if IsDefined(target) { target.SetOpacity(0.8); }
  }

  private func Act(evt: ref<inkPointerEvent>, k: Int32) -> Void {
    if !evt.IsAction(n"click") { return; }
    let s = WNCSystem.Get();
    if !IsDefined(s) { return; }
    this.m_note = k == 0 ? s.Ask() : s.UnlockPost(k);
    this.m_deviceLogicController.LoadPageByAddress(WNCUI.Address());
  }

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
