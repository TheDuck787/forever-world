# Forever World (Multiplayer)

Gemeinsame Bauprojekte für dich und deinen Freund. Die Daten liegen in Supabase, die Seite läuft kostenlos auf GitHub Pages. Änderungen erscheinen auf allen offenen Geräten ohne Neuladen.

## Dateien

| Datei | Zweck |
|---|---|
| `index.html` | Die Website (Design und Funktionen wie bisher, jetzt mit Anmeldung und Synchronisierung) |
| `config.js` | Project-URL und Publishable Key. Beides ist öffentlich und darf auf GitHub liegen |
| `export-lokal.html` | Sichert alte lokale Projekte aus einem Browser als `fw-export.json` |
| `supabase/migrations/0001_init.sql` | Tabellen, Zugriffsregeln, Bild-Speicher, Realtime (bei dir bereits ausgeführt) |

## Sicherheit

- Im Frontend stehen nur die Project-URL und der Publishable Key. Der `service_role`-Key und der Secret Key kommen nirgends vor und dürfen nie in eine Datei oder zu GitHub.
- Alle Tabellen und der Bild-Bucket sind durch Row Level Security geschützt. Zugriff hat nur, wer angemeldet ist **und** dessen E-Mail in `allowed_emails` steht. Nicht angemeldete Besucher haben auf nichts Zugriff.
- Prüfstand der Datenbank (gelesen am 17.10.2026): RLS an allen 7 Tabellen, eine Policy `members_all` je Datentabelle, 4 Policies auf dem Bucket `inspiration` (privat), `anon` hat keine Tabellenrechte, Realtime ist auf allen 6 Datentabellen aktiv, beide Konten stehen in `allowed_emails`.

## Was du noch in Supabase einstellen musst

1. **Registrierung für Fremde ausschalten:** Authentication → Sign In / Providers → „Allow new users to sign up" aus. Selbst wenn sich jemand registrieren könnte, sähe er ohne Eintrag in `allowed_emails` nichts.
2. **Adresse der Seite eintragen**, sobald GitHub Pages läuft: Authentication → URL Configuration → Site URL auf `https://DEIN-NAME.github.io/forever-world/`.
3. **Optional, Passwort-Schutz:** Authentication → Sign In / Providers → „Prevent use of leaked passwords". Das ist bei Supabase teils nur im bezahlten Tarif verfügbar. Nimm ein langes, einmaliges Passwort.
4. **Optional, Rechte verschärfen** (löscht keine Daten). Im SQL Editor ausführen:

```sql
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;
```

Die drei Hinweise im Supabase-Sicherheitscheck sind gewollt: `allowed_emails` hat absichtlich keine Policy (niemand kommt über die API heran), `is_member()` darf von Angemeldeten aufgerufen werden (liefert nur ja/nein für die eigene E-Mail), und der Passwort-Leak-Schutz ist der Punkt 3 oben.

**Wichtig beim kostenlosen Tarif:** Supabase pausiert kostenlose Projekte nach etwa einer Woche ohne Aktivität. Öffne die Seite mindestens einmal pro Woche, oder starte das Projekt im Dashboard über „Restore project" wieder. Die Daten bleiben erhalten.

## Zugang für eine weitere Person

1. Authentication → Users → Add user → Create new user (E-Mail, Passwort, „Auto Confirm User").
2. Im SQL Editor: `insert into public.allowed_emails (email) values ('name@mail.de');` (klein geschrieben).

## Kostenlos hosten mit GitHub Pages

1. Auf github.com ein neues Repository `forever-world` anlegen. Für den kostenlosen Tarif muss es **Public** sein. Das ist unkritisch: Der Code enthält keine Geheimnisse, und die Daten sind nur nach Anmeldung lesbar.
2. Im Repository „Add file → Upload files" und diese Dateien hochladen: `index.html`, `config.js`, `export-lokal.html`, `README.md`, `.gitignore` und den Ordner `supabase`. Mit „Commit changes" bestätigen.
3. Settings → Pages → Source „Deploy from a branch", Branch `main`, Ordner `/ (root)` → Save.
4. Nach ein bis zwei Minuten steht die Adresse oben auf der Pages-Seite: `https://DEIN-NAME.github.io/forever-world/`. Diese Adresse in Supabase eintragen (Punkt 2 oben) und deinem Freund schicken.

Änderungen später: Datei im Repository ersetzen und committen, nach etwa einer Minute ist die neue Version online.

## Alte lokale Daten übernehmen

Die alten Projekte liegen nur im Browser, in dem du die Seite bisher benutzt hast. Der Browser trennt Daten nach Adresse. Auf der neuen GitHub-Pages-Adresse sind sie daher zunächst nicht sichtbar.

1. Öffne `export-lokal.html` im selben Browser und auf derselben Adresse wie die alte Seite (lokale Datei: einfach per Doppelklick öffnen). Sie zeigt, wie viele Projekte und Bilder gefunden wurden. Sie liest nur und löscht nichts.
2. „Als Datei speichern" ergibt `fw-export.json`. Falls der Download nicht klappt, „In Zwischenablage kopieren".
3. Auf der neuen Seite anmelden, unten auf der Startseite „Lokale Daten aus Datei importieren", Datei wählen oder Text einfügen, „Importieren".

Läuft die neue Seite auf derselben Adresse wie die alte (zum Beispiel beim Testen aus derselben lokalen Datei), erscheint oben ein Hinweis mit dem Knopf „Hochladen".

Der Import legt nichts doppelt an und überschreibt keine Änderungen, die in der Datenbank schon stehen. Die lokalen Daten bleiben unangetastet.

## So funktioniert die Synchronisierung

- Beim Öffnen werden alle Daten aus der Datenbank geladen. Danach schickt Supabase Realtime jede Änderung an alle offenen Geräte.
- Änderungen sind sofort sichtbar und werden im Hintergrund gespeichert. Oben neben dem Titel steht „live", „speichert …" oder „offline".
- Jedes Feld wird einzeln gespeichert. Bearbeiten zwei Personen verschiedene Felder desselben Projekts, bleibt beides erhalten. Bei demselben Feld gewinnt die spätere Änderung.
- Blöcke, Aufgaben und Bilder sind eigene Einträge. Dieselbe Block-Bezeichnung kann in einer Palette nur einmal vorkommen.
- Bricht die Verbindung ab, lädt die Seite nach dem Wiederverbinden alle Daten neu.
- Nicht synchronisiert und pro Gerät: Ton an/aus und die Minecraft-Texturen aus deiner `.jar`.
- Bilder werden wie bisher auf höchstens 1400 Pixel verkleinert und in einem privaten Bucket abgelegt. Die Anzeige läuft über Links, die 12 Stunden gelten.

## Testen mit zwei Geräten

1. Auf PC und Handy (oder zwei Browsern) die Seite öffnen und mit je einem Konto anmelden.
2. Auf Gerät 1 ein Projekt anlegen und benennen. Auf Gerät 2 erscheint es von selbst.
3. Auf Gerät 2 eine Palette anlegen und Blöcke wählen. Gerät 1 sieht sie nach dem Öffnen des Projekts.
4. Auf Gerät 1 ein Bild hochladen und auf Gerät 2 in der Inspiration ansehen.
5. Auf Gerät 1 eine Aufgabe abhaken. Der Haken erscheint auf Gerät 2.

## Zugriffsregeln selbst prüfen (optional)

Im SQL Editor ausführen. Der Test legt Testdaten an und bricht am Ende absichtlich mit einer Meldung ab, damit nichts gespeichert bleibt. Erwartet wird: Mitglied sieht 1 Projekt, Fremder sieht 0, Fremder kann nichts einfügen, ändern, löschen oder hochladen, Anon hat keinen Zugriff.

```sql
do $$
declare r text := ''; n int; m text;
begin
  select email into m from public.allowed_emails limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub','00000000-0000-0000-0000-000000000001','role','authenticated','email',m)::text, true);
  set local role authenticated;
  insert into public.projects(id,name) values('rls-test','x');
  select count(*) into n from public.projects; r := r || 'Mitglied sieht '||n||' Projekt; ';
  perform set_config('request.jwt.claims', json_build_object('sub','00000000-0000-0000-0000-000000000002','role','authenticated','email','fremd@example.com')::text, true);
  select count(*) into n from public.projects; r := r || 'Fremder sieht '||n||' Projekte; ';
  begin insert into public.projects(id,name) values('rls-evil','y'); r := r || 'Fremder INSERT ERLAUBT (Fehler); '; exception when others then r := r || 'Fremder INSERT blockiert; '; end;
  begin insert into storage.objects(bucket_id,name) values('inspiration','rls/evil.jpg'); r := r || 'Fremder Upload ERLAUBT (Fehler); '; exception when others then r := r || 'Fremder Upload blockiert; '; end;
  set local role anon;
  begin select count(*) into n from public.projects; r := r || 'Anon sieht '||n||' (Fehler); '; exception when others then r := r || 'Anon ohne Zugriff; '; end;
  raise exception 'ERGEBNIS: %', r;
end $$;
```

## Datenmodell

| Tabelle | Inhalt |
|---|---|
| `projects` | Bauprojekt: Name, Notizen, Koordinaten |
| `palettes` | Paletten eines Projekts |
| `palette_blocks` | ein Block pro Zeile, Name pro Palette eindeutig |
| `todo_lists`, `todo_items` | Listen und Aufgaben mit Erledigt-Status |
| `images` | Verweise auf Bilder im Bucket `inspiration` |
| `allowed_emails` | Zugangsliste, über die API nicht lesbar |

Löschen eines Projekts löscht automatisch seine Paletten, Blöcke, Listen, Aufgaben und Bilder.

## Umgebungsvariablen

Es gibt keine. Die Seite läuft ohne Build und ohne Server. Die einzigen Werte stehen in `config.js` (Project-URL und Publishable Key, beide aus Supabase unter Project Settings → API Keys).
