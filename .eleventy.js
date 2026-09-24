module.exports = function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy({ "site/assets": "assets" });
  eleventyConfig.addFilter("displayDate", (value) =>
    new Intl.DateTimeFormat("en", {
      day: "numeric",
      month: "long",
      year: "numeric",
      timeZone: "UTC",
    }).format(new Date(value)),
  );
  eleventyConfig.addFilter("isoDate", (value) =>
    new Date(value).toISOString().slice(0, 10),
  );
  eleventyConfig.addCollection("entries", (api) =>
    api
      .getFilteredByGlob("site/journal/*.md")
      .filter((entry) => !entry.data.draft)
      .sort((a, b) => b.date - a.date),
  );
  return {
    dir: {
      input: "site",
      output: "_site",
      includes: "_includes",
      data: "_data",
    },
    pathPrefix: process.env.SITE_PATH_PREFIX || "/",
    markdownTemplateEngine: false,
    htmlTemplateEngine: "njk",
  };
};
