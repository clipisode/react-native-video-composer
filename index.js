const { NativeModules } = require("react-native");

// const { SnapchatCreativeManager } = NativeModules;

// module.exports.share = SnapchatCreativeManager && SnapchatCreativeManager.share;

module.exports.compose = function () {
  return new Promise(resolve => resolve("Hello, world!"));
};
