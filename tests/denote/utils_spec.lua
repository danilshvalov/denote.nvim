local utils = require("denote.utils")
local config = require("denote.config")

describe("sluggify", function()
  local keywords = config.options.keywords

  it("name", function()
    assert.equals(
      "this-is-a-test",
      utils.sluggify_name(" ___ !~!!$%^ This iS a tEsT ++ ?? ")
    )
  end)
  it("name and join", function()
    assert.equals(
      "thisisatest",
      utils.sluggify_name_and_join(" ___ !~!!$%^ This iS a tEsT ++ ?? ")
    )
  end)
  it("signature", function()
    assert.equals(
      "this=is=a=test",
      utils.sluggify_signature(" ___ !~!!$%^ This iS a tEsT ++ ?? ")
    )
  end)
  it("keyword single word", function()
    assert.are.same(
      { "oneone", "two", "three" },
      utils.sluggify_keywords({
        "one !@# one",
        "   two",
        "__  three  __",
      }, {
        multi_word = false,
      })
    )
  end)
  it("keyword multi word", function()
    assert.are.same(
      { "one-one", "two", "three" },
      utils.sluggify_keywords({
        "one !@# one",
        "   two",
        "__  three  __",
      }, {
        multi_word = true,
      })
    )
  end)
  it("desluggify", function()
    assert.equals("This is a test", utils.desluggify("this-is-a-test"))
  end)
end)
