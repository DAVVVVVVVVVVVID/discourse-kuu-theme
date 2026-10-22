// 聊天里分享位置（2026-10-22，Issue #24 第 2 条）的共用逻辑：浏览器定位、地点搜索、预览小地图、发出去的文字。
// 地点搜索用 OpenStreetMap 的 Nominatim（支持中文 / 日文结果，范围限定日本、优先京都附近）。
// 遵守它的使用规定（https://operations.osmfoundation.org/policies/nominatim/）：
// 只在用户点「搜索」时请求、不做输入时自动补全、两次请求至少隔 1 秒、浏览器自动带 Referer 标明来源、界面上写署名。
// 预览小地图是 OpenStreetMap 的一张地图图块（同样要署名），拿不到时只显示坐标

const NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
const TILE_URL = "https://tile.openstreetmap.org";
const MIN_INTERVAL_MS = 1000;
// 京都市中心附近，搜索时优先这一带（不限死，京都站、大阪也能搜到）
const KYOTO_VIEWBOX = "135.60,35.15,135.90,34.88";

let lastSearchAt = 0;

export const OSM_ATTRIBUTION = "地图数据 © OpenStreetMap 贡献者";

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// 返回 { lat, lng }；失败时抛出带中文说明的错误
export function currentPosition() {
  return new Promise((resolve, reject) => {
    if (!window.isSecureContext || !navigator.geolocation) {
      reject(new Error("这个浏览器不能取得位置。可以改用下面的「搜索地点」"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (position) =>
        resolve({
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        }),
      (error) => {
        const messages = {
          1: "没有定位权限。请在浏览器或手机的设置里允许京圈使用位置，或者改用下面的「搜索地点」",
          2: "现在拿不到位置信号，请稍后再试，或者改用下面的「搜索地点」",
          3: "定位超时了，请再试一次，或者改用下面的「搜索地点」",
        };
        reject(new Error(messages[error.code] || "取得位置失败"));
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }
    );
  });
}

// 返回 [{ name, address, lat, lng }]
export async function searchPlaces(query) {
  const since = Date.now() - lastSearchAt;
  if (since < MIN_INTERVAL_MS) {
    await wait(MIN_INTERVAL_MS - since);
  }
  lastSearchAt = Date.now();

  const params = new URLSearchParams({
    q: query,
    format: "jsonv2",
    addressdetails: "0",
    limit: "8",
    countrycodes: "jp",
    viewbox: KYOTO_VIEWBOX,
    "accept-language": "zh-CN,zh,ja",
  });
  const response = await fetch(`${NOMINATIM_URL}?${params}`, {
    headers: { Accept: "application/json" },
  });
  if (!response.ok) {
    throw new Error("地点搜索暂时用不了，请稍后再试");
  }
  const results = await response.json();
  // 同一个地方常有好几个点（比如同名的几个公交站），名字和地址都一样的只留第一个
  const seen = new Set();
  return results
    .map((place) => {
      const parts = (place.display_name || "").split(",").map((t) => t.trim());
      return {
        name: place.name || parts[0] || query,
        address: parts.slice(1, 4).join("，"),
        lat: parseFloat(place.lat),
        lng: parseFloat(place.lon),
      };
    })
    .filter((place) => {
      const key = `${place.name}|${place.address}`;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
}

// 预览小地图：以地点为中心的 3×3 张 OpenStreetMap 图块（每张 256px），拼起来再从正中间裁出 256×256，
// 地点永远在正中间（只用一张图块时，地点靠近图块边缘会被切掉）。
// 返回 tiles：[{ url, left, top }]（相对于裁出来的方框，单位 px）
const TILE_SIZE = 256;

export function previewTiles(lat, lng, zoom = 16) {
  const n = 2 ** zoom;
  const latRad = (lat * Math.PI) / 180;
  // 地点在整张世界地图上的像素位置
  const px = ((lng + 180) / 360) * n * TILE_SIZE;
  const py =
    ((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2) *
    n *
    TILE_SIZE;
  const centerX = Math.floor(px / TILE_SIZE);
  const centerY = Math.floor(py / TILE_SIZE);
  // 方框左上角在世界地图上的位置
  const originX = px - TILE_SIZE / 2;
  const originY = py - TILE_SIZE / 2;

  const tiles = [];
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const x = centerX + dx;
      const y = centerY + dy;
      tiles.push({
        url: `${TILE_URL}/${zoom}/${((x % n) + n) % n}/${y}.png`,
        left: Math.round(x * TILE_SIZE - originX),
        top: Math.round(y * TILE_SIZE - originY),
      });
    }
  }
  return tiles;
}

export function formatCoordinates(lat, lng) {
  return `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
}

export function googleMapsUrl(lat, lng) {
  return `https://www.google.com/maps?q=${lat.toFixed(6)},${lng.toFixed(6)}`;
}

// 发出去的消息：一行「📍 地点名」+ Google 地图链接（手机上点开能用地图导航）
export function locationMessage(place) {
  return `📍 ${place.name}\n${googleMapsUrl(place.lat, place.lng)}`;
}
