// lint-staged.config.js
module.exports = {
    '**/*.{cls,trigger,page,component}': (filenames) => `sf scanner run -f table -s 3 -t ${filenames.join(', ')}`,
};
