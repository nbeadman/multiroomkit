module.exports = {
  layout: "entry.njk",
  author: "OpenAI Codex",
  eleventyComputed: {
    permalink: (data) =>
      data.draft ? false : `/journal/${data.page.fileSlug}/index.html`,
    eleventyExcludeFromCollections: (data) => Boolean(data.draft),
  },
};
