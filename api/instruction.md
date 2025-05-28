## ✅ Instrukcja do testowania API

### 📦 API
API jest dostępne pod adresem:

```
https://ktm-testing-api.onrender.com/
```

### 🔐 Autoryzacja

Aby korzystać z większości endpointów, musisz najpierw uwierzytelnić się i uzyskać **JWT token**.

#### 1. Endpoint autoryzacyjny

```
POST /auth
```

**Nagłówek:**

```
Authorization: Basic base64(admin:secret)
```

**Odpowiedź:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5..."
}
```

---

### 📌 Używanie tokena JWT

Dla każdego endpointu poza `/auth` wymagany jest nagłówek:

```
Authorization: Bearer <TWÓJ_TOKEN>
```

Token jest ważny przez 1 godzinę od wygenerowania.

---

## 📘 Endpointy

### 🔹 Użytkownicy

- `GET /users` – lista użytkowników
- `GET /users/:id` – szczegóły konkretnego użytkownika
- `POST /users` – tworzenie użytkownika `{ "name": "Imię" }`

---

### 🔹 Zadania użytkownika

- `GET /users/:id/tasks` – zadania użytkownika

  **Filtry dostępne jako query params:**

    - `done=true/false` – filtruj po statusie
    - `created_after=<timestamp>`
    - `created_before=<timestamp>`

- `POST /users/:id/tasks` – dodanie zadania `{ "title": "Zadanie", "done": false }`

- `GET /users/:user_id/tasks/:task_id` – szczegóły zadania

- `PUT /users/:user_id/tasks/:task_id` – edycja zadania

- `DELETE /users/:user_id/tasks/:task_id` – usunięcie zadania

---

### 🔹 Globalne zadania

- `GET /tasks` – lista wszystkich zadań

  **Filtry:**

    - `done=true/false`
    - `from=<timestamp>`
    - `to=<timestamp>`

- `GET /tasks/:id` – szczegóły zadania (zawiera dane użytkownika)

---

## 📋 Zadania rekrutacyjne

### 1. 🔐 Autoryzacja

- Przetestuj endpoint `/auth`.
- Sprawdź zachowanie dla:
    - Braku nagłówka
    - Nieprawidłowego loginu/hasła
    - Poprawnych danych

### 2. ✅ Token JWT

- Upewnij się, że po zalogowaniu token działa dla innych endpointów.
- Sprawdź zachowanie po usunięciu lub manipulacji tokenem.
- Sprawdź co się dzieje po jego wygaśnięciu (można zmanipulować `exp` w tokenie).

### 3. 👤 Użytkownicy

- Przetestuj dodawanie nowego użytkownika.
- Upewnij się, że tworzy się unikalny `id`.
- Sprawdź odpowiedź przy braku pola `name`.

### 4. 📋 Zadania

- Dodaj zadanie do użytkownika i sprawdź czy zostało zapisane.
- Zmodyfikuj zadanie.
- Usuń zadanie i sprawdź, czy zniknęło.
- Przetestuj filtrowanie po statusie i czasie.

### 5. ❌ Błędy

- Przetestuj brakujące parametry
- Błędne ID użytkownika lub zadania
- Brak autoryzacji

