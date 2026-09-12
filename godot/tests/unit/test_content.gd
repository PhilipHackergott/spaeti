extends "res://tests/TestCase.gd"
## Content integrity: the registries must be internally consistent or the night silently misbehaves.

func test_registry_loads() -> void:
	assert_true(Content.SKUS.size() >= 18, "SKU catalogue ported (got %d)" % Content.SKUS.size())
	assert_eq(Content.SKU_BY_ID.size(), Content.SKUS.size(), "SKU ids unique")
	assert_eq(Content.ARCHETYPE_BY_ID.size(), Content.ARCHETYPES.size(), "archetype ids unique")
	assert_eq(Content.UPGRADE_BY_ID.size(), Content.UPGRADES.size(), "upgrade ids unique")
	assert_eq(Content.STRAND_BY_ID.size(), Content.STRANDS.size(), "strand ids unique")
	assert_eq(Content.VIGNETTE_BY_ID.size(), Content.VIGNETTES.size(), "vignette ids unique")
	assert_eq(Content.CHARACTER_BY_ID.size(), Content.CHARACTERS.size(), "character ids unique")
