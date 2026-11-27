// Whispers of Night City - one-shot intro contact "WHISPERS".
// At character level 5 (checked on the street triggers: district entered / V stepped out of a vehicle) WHISPERS texts V
// once, pointing at the website. The contact stays in the phone for 3 game days, read or not, then is gone for good.
// Never sent to a V who already opened the site (wnc_day > 0). Script-only contact like Boosting's BOOSTER: no journal
// entry, so removing it is just not adding the row any more.
// Facts: wnc_intro 0 = not sent, 1 = on the phone, 2 = done; wnc_introt = send time (WNC.Now()); wnc_intror = 1 once read.

public class WNCMsgData extends IScriptable {
  public let text: String;
}

public class WNCNotifData extends JournalNotificationData {}

public class WNCOpenPhoneAction extends GenericNotificationBaseAction {
  public func Execute(data: ref<IScriptable>) -> Bool {
    let ps = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"PhoneSystem") as PhoneSystem;
    if IsDefined(ps) { ps.QueueRequest(new UsePhoneRequest()); }
    return true;
  }

  public func GetLabel() -> String = "Open Phone"
}

public class WNCPhone extends ScriptableSystem {
  private let m_phone: wref<NewHudPhoneGameController>;

  public static func Get() -> ref<WNCPhone> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"WNCPhone") as WNCPhone;
  }

  public static func Hash() -> Int32 = 1464746752 // 0x574E4300 "WNC" (no journal entry has it)
  public static func Name() -> String = "WHISPERS"
  public static func Level() -> Float = 5.0
  public static func KeepSeconds() -> Int32 = 3 * 86400 // 3 game days
  public static func Text() -> String = "The city talks, choom. Most people don't listen. You look like you might. Jack into "
    + WNCUI.Address() + " on any computer: rumours, stashes, things people lost and never came back for. You might find something interesting there."

  // the contact is on the phone; expires lazily (any check after 3 game days ends it)
  public func Active() -> Bool {
    if WNC.F("wnc_intro") != 1 { return false; }
    if WNC.Now() - WNC.F("wnc_introt") < WNCPhone.KeepSeconds() { return true; }
    WNC.SetF("wnc_intro", 2);
    return false;
  }

  // street trigger: send once at level 5
  public func Check() -> Void {
    if WNC.F("wnc_intro") != 0 { this.Active(); return; }
    let s = WNCSystem.Get();
    if !IsDefined(s) || !s.Started() { return; }
    if WNC.F("wnc_day") > 0 { WNC.SetF("wnc_intro", 2); return; } // already found the site on their own
    let p = GetPlayer(this.GetGameInstance());
    if !IsDefined(p) { return; }
    let lvl = GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(p.GetEntityID()), gamedataStatType.Level);
    if lvl < WNCPhone.Level() { return; }
    WNC.SetF("wnc_intro", 1);
    WNC.SetF("wnc_introt", WNC.Now());
    this.Notify();
  }

  public func Row() -> ref<ContactData> {
    let row = new ContactData();
    row.hash = WNCPhone.Hash();
    row.localizedName = WNCPhone.Name();
    row.contactId = "WHISPERSNC_WHISPERS";
    row.id = "WHISPERSNC_WHISPERS";
    row.avatarID = t"PhoneAvatars.Avatar_Unknown";
    row.isCallable = false;
    row.type = MessengerContactType.SingleThread;
    row.lastMesssagePreview = WNCPhone.Text();
    row.timeStamp = this.Stamp();
    row.messagesCount = 1;
    row.hasMessages = true;
    row.playerCanReply = false;
    this.ApplyUnread(row);
    return row;
  }

  public func ApplyUnread(row: ref<ContactData>) -> Void {
    ArrayClear(row.unreadMessages);
    if WNC.F("wnc_intror") == 0 { ArrayPush(row.unreadMessages, WNCPhone.Hash()); }
    row.unreadMessegeCount = ArraySize(row.unreadMessages);
  }

  public func Data(contactData: wref<ContactData>, source: PhoneScreenType) -> ref<WNCNotifData> {
    let d = new WNCNotifData();
    d.type = contactData.type;
    d.contactNameLocKey = StringToName(contactData.localizedName);
    d.mode = JournalNotificationMode.HUD;
    d.openedFromPhone = true;
    d.source = source;
    return d;
  }

  // send time as GameTime (saved as seconds in wnc_introt)
  public func Stamp() -> GameTime {
    let t = WNC.F("wnc_introt");
    return GameTime.MakeGameTime(t / 86400, (t % 86400) / 3600, (t % 3600) / 60, 0);
  }

  public func MarkRead() -> Void { WNC.SetF("wnc_intror", 1); }
  public func SetPhone(phone: ref<NewHudPhoneGameController>) -> Void { this.m_phone = phone; }

  // popup "WHISPERS: <text>" (opens the phone); without a phone controller the contact still shows, unread
  private func Notify() -> Void {
    let phone = this.m_phone;
    if !IsDefined(phone) { return; }
    let userData = new PhoneMessageNotificationViewData();
    userData.title = WNCPhone.Name();
    userData.SMSText = WNCPhone.Text();
    userData.contactHash = WNCPhone.Hash();
    userData.threadHash = WNCPhone.Hash();
    userData.action = new WNCOpenPhoneAction();
    userData.animation = n"notification_phone_MSG";
    userData.soundEvent = n"PhoneSmsPopup";
    userData.soundAction = n"OnOpen";
    let nd: gameuiGenericNotificationData;
    nd.time = 6.7;
    nd.widgetLibraryItemName = n"notification_message";
    nd.notificationData = userData;
    phone.AddNewNotificationData(nd);
  }
}

// ---------------------------------------------------------------- contact list + opening our thread

@wrapMethod(MessengerUtils)
public final static func GetSimpleContactDataArray(journal: ref<JournalManager>, includeUnknown: Bool, skipEmpty: Bool, includeWithNoUnread: Bool, opt activeDataSync: wref<MessengerContactSyncData>) -> array<ref<IScriptable>> {
  let data = wrappedMethod(journal, includeUnknown, skipEmpty, includeWithNoUnread, activeDataSync);
  let sys = WNCPhone.Get();
  if IsDefined(sys) && sys.Active() {
    let row = sys.Row();
    if includeWithNoUnread || ArraySize(row.unreadMessages) > 0 { ArrayPush(data, row); }
  }
  return data;
}

@wrapMethod(NewHudPhoneGameController)
protected cb func OnInitialize() -> Bool {
  let r = wrappedMethod();
  let sys = WNCPhone.Get();
  if IsDefined(sys) { sys.SetPhone(this); }
  return r;
}

@wrapMethod(NewHudPhoneGameController)
protected cb func OnPlayerAttach(playerPuppet: ref<GameObject>) -> Bool {
  let r = wrappedMethod(playerPuppet);
  let sys = WNCPhone.Get();
  if IsDefined(sys) { sys.SetPhone(this); }
  return r;
}

@wrapMethod(NewHudPhoneGameController)
public final func GotoSmsMessenger(contactData: wref<ContactData>) -> Void {
  let sys = WNCPhone.Get();
  if IsDefined(contactData) && contactData.hash == WNCPhone.Hash() && IsDefined(sys) {
    let evt = new OpenSmsMessengerEvent();
    evt.m_data = sys.Data(contactData, this.m_screenType);
    this.QueueEvent(evt);
    return;
  }
  wrappedMethod(contactData);
}

@wrapMethod(NewHudPhoneGameController)
public final func RefreshSmsMessager(contactData: wref<ContactData>) -> Void {
  let sys = WNCPhone.Get();
  if IsDefined(contactData) && contactData.hash == WNCPhone.Hash() && IsDefined(sys) {
    let evt = new RefreshSmsMessagerEvent();
    evt.m_data = sys.Data(contactData, this.m_screenType);
    this.QueueEvent(evt);
    return;
  }
  wrappedMethod(contactData);
}

@wrapMethod(NewHudPhoneGameController)
public final func RefreshReplies(contactData: ref<ContactData>) -> Bool {
  let sys = WNCPhone.Get();
  if IsDefined(contactData) && contactData.hash == WNCPhone.Hash() && IsDefined(sys) {
    sys.ApplyUnread(contactData);
    return false;
  }
  return wrappedMethod(contactData);
}

@wrapMethod(PhoneMessagePopupGameController)
private final func SetFocus(isFocused: Bool) -> Void {
  if NotEquals(this.m_isFocused, isFocused) && IsDefined(this.m_data as WNCNotifData) {
    if isFocused {
      this.m_dialogViewController.WNCShow();
      inkWidgetRef.SetVisible(this.m_hintCall, false);
    } else {
      this.m_dialogViewController.WNCClose();
    }
  }
  wrappedMethod(isFocused);
}

// ---------------------------------------------------------------- our thread in the vanilla message panel

@addField(MessengerDialogViewController)
private let m_wncActive: Bool;

@addMethod(MessengerDialogViewController)
public final func WNCShow() -> Void {
  this.m_contactHash = WNCPhone.Hash();
  this.m_parentHash = WNCPhone.Hash();
  ArrayClear(this.m_messages);
  ArrayClear(this.m_replyOptions);
  this.WNCRender();
}

@addMethod(MessengerDialogViewController)
public final func WNCClose() -> Void {
  if !this.m_wncActive { return; }
  this.m_wncActive = false;
  this.m_contactHash = 0;
  this.m_messagesListController.Clear();
  this.m_choicesListController.Clear();
}

@addMethod(MessengerDialogViewController)
private final func WNCRender() -> Void {
  this.m_wncActive = true;
  let m = new WNCMsgData();
  m.text = WNCPhone.Text();
  let d = new JournalEntryListItemData();
  d.m_extraData = m;
  let list: array<ref<IScriptable>>;
  ArrayPush(list, d);
  this.m_messagesListController.Clear();
  this.m_messagesListController.PushDataList(list, true);
  this.m_choicesListController.Clear();
  inkWidgetRef.SetVisible(this.m_replayFluff, false);
  let sys = WNCPhone.Get();
  if IsDefined(sys) { sys.MarkRead(); }
  this.m_scrollController.SetScrollPosition(1.0);
}

@wrapMethod(MessengerDialogViewController)
public final func UpdateData(animateLastMessage: Bool, setVisited: Bool) -> Void {
  if this.m_contactHash == WNCPhone.Hash() {
    this.WNCRender();
    return;
  }
  wrappedMethod(animateLastMessage, setVisited);
}

@wrapMethod(MessengerDialogViewController)
public final func SetCurrentMessagesAsVisited() -> Void {
  if this.m_contactHash == WNCPhone.Hash() {
    let sys = WNCPhone.Get();
    if IsDefined(sys) { sys.MarkRead(); }
    return;
  }
  wrappedMethod();
}

@wrapMethod(MessengerDialogViewController)
public final func HasReplyOptions() -> Bool {
  if this.m_contactHash == WNCPhone.Hash() { return false; }
  return wrappedMethod();
}

@wrapMethod(MessangerItemRenderer)
protected func OnJournalEntryUpdated(entry: wref<JournalEntry>, extraData: ref<IScriptable>) -> Void {
  let m = extraData as WNCMsgData;
  if IsDefined(m) {
    inkWidgetRef.SetVisible(this.m_image, false);
    this.SetMessageView(m.text, MessageViewType.Received, "");
    return;
  }
  wrappedMethod(entry, extraData);
}
