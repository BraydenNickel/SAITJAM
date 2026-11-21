class_name RenameDialogTest
extends GdUnitTestSuite
## Unit tests for RenameDialog.clean_name (the monster name rule).

const OLD: String = "Subject 01"

func test_trims_whitespace() -> void:
	assert_str(RenameDialog.clean_name("  Gloop \t", OLD)).is_equal("Gloop")

func test_empty_keeps_old_name() -> void:
	assert_str(RenameDialog.clean_name("", OLD)).is_equal(OLD)
	assert_str(RenameDialog.clean_name("    ", OLD)).is_equal(OLD)

func test_cut_to_max_length() -> void:
	var long_name: String = "ABCDEFGHIJKLMNOPQRST"
	var result: String = RenameDialog.clean_name(long_name, OLD)
	assert_int(result.length()).is_equal(RenameDialog.MAX_NAME_LENGTH)
	assert_str(result).is_equal(long_name.left(RenameDialog.MAX_NAME_LENGTH))

func test_exact_max_length_kept() -> void:
	var name_14: String = "N".repeat(RenameDialog.MAX_NAME_LENGTH)
	assert_str(RenameDialog.clean_name(name_14, OLD)).is_equal(name_14)

func test_cut_does_not_leave_trailing_space() -> void:
	# 13 letters, then a space at index 13, then more text.
	var raw: String = "ABCDEFGHIJKLM NOP"
	assert_str(RenameDialog.clean_name(raw, OLD)).is_equal("ABCDEFGHIJKLM")
