// Whispers of Night City: settings. Esc > Mods > "Whispers of Night City" with Mod Settings (Nexus 4885) installed;
// without it every value below is simply its default. Values are read when they are used, so changes apply at once.

@if(ModuleExists("ModSettingsModule"))
public func WNCMS_Listen(l: ref<IScriptable>) { ModSettings.RegisterListenerToClass(l); }
@if(!ModuleExists("ModSettingsModule"))
public func WNCMS_Listen(l: ref<IScriptable>) {}

public class WNCModSettings extends ScriptableService {
  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Website")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Whispers per day")
  @runtimeProperty("ModSettings.description", "New whispers posted on NETdir://nc.whispers each game day (on your first visit that day).")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "5")
  public let daily: Int32 = 3;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Website")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Whisper price: lowest")
  @runtimeProperty("ModSettings.description", "Every daily whisper costs a tip, rolled once per whisper between the lowest and the highest price.")
  @runtimeProperty("ModSettings.step", "10")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "5000")
  public let priceMin: Int32 = 50;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Website")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Whisper price: highest")
  @runtimeProperty("ModSettings.description", "Highest tip for a daily whisper.")
  @runtimeProperty("ModSettings.step", "10")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "5000")
  public let priceMax: Int32 = 300;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Website")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Ask around: start price")
  @runtimeProperty("ModSettings.description", "First extra whisper costs this; every further one doubles it (100, 200, 400 ...).")
  @runtimeProperty("ModSettings.step", "10")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "5000")
  public let askStart: Int32 = 100;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Website")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Ask around: reset after (game hours)")
  @runtimeProperty("ModSettings.description", "The doubling resets to the start price this many game hours after the first ask.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "168")
  public let askResetHours: Int32 = 24;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Street")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Overheard nearby (%)")
  @runtimeProperty("ModSettings.description", "Chance that the street reveals the nearest hidden gem when you enter a district or step out of a vehicle. 0 = off.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100")
  public let nearPct: Int32 = 20;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Street")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Overheard nearby: radius (m)")
  @runtimeProperty("ModSettings.description", "How close a hidden gem has to be.")
  @runtimeProperty("ModSettings.step", "25")
  @runtimeProperty("ModSettings.min", "50")
  @runtimeProperty("ModSettings.max", "1000")
  public let nearRadius: Int32 = 250;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Street")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Overheard nearby: game hours between rolls")
  @runtimeProperty("ModSettings.description", "At most one roll per this many game hours.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "24")
  public let nearHours: Int32 = 1;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Street")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Dogtown gems")
  @runtimeProperty("ModSettings.description", "Include the 46 Dogtown hidden gems (needs Phantom Liberty; from the moment Dogtown opens).")
  public let dogtown: Bool = true;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Rewards")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Rewards")
  @runtimeProperty("ModSettings.description", "Pay out for closed cases (every 10, and all of them).")
  public let rewards: Bool = true;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Rewards")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Every 10 cases: eddies")
  @runtimeProperty("ModSettings.description", "Eddies every 10 closed cases (plus crafting components).")
  @runtimeProperty("ModSettings.step", "50")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "5000")
  public let tierPay: Int32 = 150;

  @runtimeProperty("ModSettings.mod", "Whispers of Night City")
  @runtimeProperty("ModSettings.category", "Rewards")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "All cases: eddies")
  @runtimeProperty("ModSettings.description", "Eddies when every case is closed (plus legendary components and Comrade's Hammer).")
  @runtimeProperty("ModSettings.step", "250")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "50000")
  public let allPay: Int32 = 3000;

  private cb func OnLoad() { WNCMS_Listen(this); }
  private cb func OnReload() { WNCMS_Listen(this); }

  public static func Get() -> ref<WNCModSettings> = GameInstance.GetScriptableServiceContainer().GetService(n"WNCModSettings") as WNCModSettings
}

// read at use, clamped; defaults when the service is missing
public abstract class WNCCfg {
  public static func Daily() -> Int32 { let s = WNCModSettings.Get(); return IsDefined(s) ? Clamp(s.daily, 0, 5) : 3; }
  public static func PriceMin() -> Int32 { let s = WNCModSettings.Get(); return IsDefined(s) ? Max(s.priceMin, 0) : 50; }
  public static func PriceMax() -> Int32 { let s = WNCModSettings.Get(); return IsDefined(s) ? Max(s.priceMax, 0) : 300; }
  public static func AskStart() -> Int32 { let s = WNCModSettings.Get(); return IsDefined(s) ? Max(s.askStart, 0) : 100; }
  public static func AskResetSeconds() -> Int32 { let s = WNCModSettings.Get(); return 3600 * (IsDefined(s) ? Clamp(s.askResetHours, 1, 168) : 24); }
  public static func NearPct() -> Int32 { let s = WNCModSettings.Get(); return IsDefined(s) ? Clamp(s.nearPct, 0, 100) : 20; }
  public static func NearRadius() -> Float { let s = WNCModSettings.Get(); return Cast<Float>(IsDefined(s) ? Clamp(s.nearRadius, 50, 1000) : 250); }
  public static func NearSeconds() -> Int32 { let s = WNCModSettings.Get(); return 3600 * (IsDefined(s) ? Clamp(s.nearHours, 0, 24) : 1); }
  public static func Dogtown() -> Bool { let s = WNCModSettings.Get(); return IsDefined(s) ? s.dogtown : true; }
  public static func Rewards() -> Bool { let s = WNCModSettings.Get(); return IsDefined(s) ? s.rewards : true; }
  public static func TierPay() -> Int32 { let s = WNCModSettings.Get(); return IsDefined(s) ? Max(s.tierPay, 0) : 150; }
  public static func AllPay() -> Int32 { let s = WNCModSettings.Get(); return IsDefined(s) ? Max(s.allPay, 0) : 3000; }
}
