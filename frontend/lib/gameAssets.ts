import { getAssetUrl, getOverrideUrl } from "./assetOverrides";

export const BUILDING_ASSET_MAP: Record<string, string> = {
  port: "/assets/buildings/v2/navyport_w300.webp",
  barracks: "/assets/buildings/v2/barracks1_w300.webp",
  carrier: "/assets/buildings/v2/airport_w300.webp",
  radar: "/assets/buildings/v2/powerplant1_w300.webp",
  tower: "/assets/buildings/v2/sentry_w300.webp",
  factory: "/assets/buildings/v2/ironworks_w300.webp",
  // legacy fallbacks
  airport: "/assets/buildings/v2/airport_w300.webp",
  navy_port: "/assets/buildings/v2/navyport_w300.webp",
  power_plant: "/assets/buildings/v2/powerplant1_w300.webp",
  military_base: "/assets/buildings/v2/militarybase_w300.webp",
  ironworks: "/assets/buildings/v2/ironworks_w300.webp",
  mine: "/assets/buildings/v2/mine_w300.webp",
};

export function getBuildingAsset(slug: string | null | undefined, assetUrl?: string | null): string | null {
  if (assetUrl) return assetUrl;
  if (!slug) return null;
  // Check override by slug
  const override = getOverrideUrl(slug);
  if (override) return override;
  return BUILDING_ASSET_MAP[slug] ?? null;
}

export function getUnitAsset(kind: string | null | undefined = "default", assetUrl?: string | null): string {
  if (assetUrl) return assetUrl;
  // Check override by kind key
  const override = getOverrideUrl(kind ?? "default");
  if (override) return override;
  switch (kind) {
    case "moving":
      return "/assets/units/moving.webp";
    case "nuke_rocket":
      return "/assets/units/nuke_icon.png";
    case "air":
    case "fighter":
    case "bomber":
      return "/assets/units/planes/bomber_h300.webp";
    case "ship":
    case "ship_1":
      return "/assets/units/ships/ship1.png";
    case "tank":
    case "ground_unit_sphere":
      return "/assets/units/ground_unit_sphere_h300.png";
    case "infantry":
    case "ground_unit":
      return "/assets/units/ground_unit.webp";
    default:
      return "/assets/units/ground_unit_sphere_h300.png";
  }
}

/**
 * Resolve a building asset with player cosmetic priority.
 * Priority: playerCosmetics[slug] > global override > fallback
 */
export function getPlayerBuildingAsset(
  slug: string | null | undefined,
  playerCosmetics?: Record<string, unknown>,
  assetUrl?: string | null
): string | null {
  if (slug && playerCosmetics?.[slug]) {
    const v = playerCosmetics[slug];
    const url = typeof v === "string" ? v : typeof v === "object" && v !== null && "url" in v ? (v as { url?: string | null }).url : null;
    if (url) return url;
  }
  return getBuildingAsset(slug, assetUrl);
}

/**
 * Resolve a unit asset with player cosmetic priority.
 * Priority: playerCosmetics[kind] > global override > fallback
 */
export function getPlayerUnitAsset(
  kind: string | null | undefined,
  playerCosmetics?: Record<string, unknown>,
  assetUrl?: string | null
): string {
  const resolvedKind = kind ?? "default";
  if (playerCosmetics?.[resolvedKind]) {
    const v = playerCosmetics[resolvedKind];
    const url = typeof v === "string" ? v : typeof v === "object" && v !== null && "url" in v ? (v as { url?: string | null }).url : null;
    if (url) return url;
  }
  return getUnitAsset(kind, assetUrl);
}

export function getActionAsset(
  action: "attack" | "move" | "build" | "close" | "defense" | "players",
  unitType?: string | null
): string {
  const keyMap: Record<string, string> = {
    close: "icon_close",
    build: "icon_building",
    defense: "icon_shield",
    players: "icon_hex",
  };
  if (keyMap[action]) {
    const fallbacks: Record<string, string> = {
      close: "/assets/icons/close_w80.webp",
      build: "/assets/icons/building_icon.webp",
      defense: "/assets/visuals/shield_w100.webp",
      players: "/assets/icons/hex.webp",
    };
    return getAssetUrl(keyMap[action], fallbacks[action]);
  }

  // attack / move: unit-type based logic
  if (unitType === "fighter" || unitType === "bomber") {
    return getAssetUrl("icon_plane_tag", "/assets/units/plane_tag.png");
  }
  if (unitType === "ship" || unitType === "ship_1") {
    return action === "attack"
      ? getAssetUrl("icon_ship_attack", "/assets/units/ships/ship1_colors.png")
      : getAssetUrl("icon_ship_move", "/assets/units/ships/ship1.png");
  }

  return action === "attack"
    ? getAssetUrl("icon_attack", "/assets/icons/attack_icon.webp")
    : getAssetUrl("icon_move", "/assets/visuals/arrow_head_2.webp");
}
