const leftWallCloseImage = require('@/assets/images/left-wall-close.png');
console.log('Left wall close image loaded:', leftWallCloseImage);

export const wallImages = {
  left: {
    close: leftWallCloseImage,
    mid: null,
    far: null,
  },
  right: {
    close: null,
    mid: null,
    far: null,
  },
  back: {
    front: null,
    mid: null,
    far: null,
  },
  floor: {
    close: null,
    mid: null,
    far: null,
  },
  ceiling: {
    close: null,
    mid: null,
    far: null,
  },
  special: {
    door: null,
    stairsUp: null,
    stairsDown: null,
    corridor: null,
  },
};
