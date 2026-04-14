// npx svgo -f assets/ --recursive --config ./tools/svgo.config.js
module.exports = {
  plugins: [
    'preset-default',
    'removeMetadata',
    {
      name: 'inlineStyles',
      params: {
        onlyMatchedOnce: false
      }
    }
  ]
};