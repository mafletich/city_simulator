class_name NameGenerator
extends RefCounted

const MALE_FIRST_NAMES: Array[String] = [
	"Александр", "Дмитрий", "Максим", "Сергей", "Андрей",
	"Иван", "Никита", "Егор", "Артём", "Кирилл",
]

const FEMALE_FIRST_NAMES: Array[String] = [
	"Анна", "Мария", "Елена", "Ольга", "Наталья",
	"Виктория", "Дарья", "Екатерина", "Юлия", "Софья",
]

const LAST_NAMES: Array[String] = [
	"Иванов", "Смирнов", "Кузнецов", "Попов", "Соколов",
	"Лебедев", "Козлов", "Новиков", "Морозов", "Волков",
]

const FINGERPRINT_CHARS: String = "0123456789ABCDEF"

static func random_first_name(gender: Enums.Gender) -> String:
	if gender == Enums.Gender.MALE:
		return MALE_FIRST_NAMES[randi() % MALE_FIRST_NAMES.size()]
	return FEMALE_FIRST_NAMES[randi() % FEMALE_FIRST_NAMES.size()]

static func random_last_name(gender: Enums.Gender) -> String:
	var base_name := LAST_NAMES[randi() % LAST_NAMES.size()]
	if gender == Enums.Gender.FEMALE:
		return base_name + "а"
	return base_name

static func random_fingerprint() -> String:
	var s := ""
	for i in range(16):
		s += FINGERPRINT_CHARS[randi() % FINGERPRINT_CHARS.length()]
	return s
