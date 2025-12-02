const PROJECT_ID = 'qzw6qd8m3bpcd6vswghkx';

export function getProjectAssetUrl(assetKey: string): string {
  const cleanKey = assetKey.startsWith('@') ? assetKey.slice(1) : assetKey;
  return `https://rork.app/pa/${PROJECT_ID}/${cleanKey}`;
}
