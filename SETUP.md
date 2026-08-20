# KayPam — Guide de déploiement (gratuit)

Ce guide vous emmène de zéro jusqu'à un site KayPam en ligne, avec une vraie
base de données, un vrai stockage de photos/vidéos, et un vrai compte admin
sécurisé. Aucune commande, tout se fait par clics dans deux interfaces web
(Supabase et Netlify).

Temps estimé : 30-45 minutes la première fois.

---

## Partie 1 — Créer la base de données (Supabase)

1. Allez sur **https://supabase.com** et créez un compte gratuit (avec Google
   ou GitHub, c'est le plus rapide).
2. Cliquez **"New Project"**.
   - Nom : `kaypam`
   - Mot de passe de base de données : générez-en un et **notez-le quelque part**
     (vous n'en aurez pas besoin au quotidien, mais gardez-le en sécurité).
   - Région : choisissez la plus proche d'Haïti (ex. `East US`).
   - Cliquez **"Create new project"** et patientez ~2 minutes.

3. Une fois le projet prêt, allez dans **"SQL Editor"** (icône dans le menu
   de gauche).
4. Cliquez **"New query"**, ouvrez le fichier `schema.sql` fourni, copiez
   **tout** son contenu, collez-le dans l'éditeur, puis cliquez **"Run"**.
   - Vous devriez voir "Success. No rows returned" — c'est normal.

5. Allez dans **"Storage"** (menu de gauche).
   - Cliquez **"New bucket"**.
   - Nom exact : `listing-media` (respectez la casse et les tirets).
   - Activez **"Public bucket"**.
   - Cliquez **"Create bucket"**.

6. Retournez dans **"SQL Editor"**, ouvrez une nouvelle requête, et exécutez
   les **deux dernières requêtes** du fichier `schema.sql` (celles qui
   commencent par `create policy "media_bucket_public_read"` et
   `"media_bucket_public_upload"`). Elles doivent être exécutées **après**
   la création du bucket, pas avant.

7. Créez votre compte administrateur :
   - Allez dans **"Authentication" → "Users"**.
   - Cliquez **"Add user" → "Create new user"**.
   - Entrez votre email et un mot de passe solide.
   - Décochez "Auto Confirm User" n'est pas nécessaire — laissez la case
     cochée si présente, pour pouvoir vous connecter immédiatement.
   - C'est cet email/mot de passe que vous utiliserez pour vous connecter
     sur `admin.html`.

8. **⚠️ Étape critique — désactivez la confirmation par email :**
   - Allez dans **"Authentication" → "Providers"** (ou **"Sign In / Providers"**
     selon la version).
   - Cliquez sur **"Email"**.
   - Désactivez **"Confirm email"**.
   - Cliquez **"Save"**.
   - **Pourquoi c'est obligatoire** : les comptes propriétaires KayPam
     utilisent un nom d'utilisateur, pas un vrai email — le système fabrique
     une fausse adresse (`username@kaypam.local`) en coulisses. Si la
     confirmation par email reste activée, Supabase essaiera d'envoyer un
     email de confirmation à cette fausse adresse, qui n'existera jamais,
     et **aucun propriétaire ne pourra jamais confirmer son compte ni se
     connecter.**

9. **⚠️ Étape critique — ajoutez votre admin dans la table `admins` :**
   - Retournez dans **"SQL Editor"**, ouvrez une nouvelle requête.
   - Collez ceci, en remplaçant `VOTRE_EMAIL_ADMIN` par l'email exact utilisé
     à l'étape 7 :
     ```sql
     insert into admins (user_id)
     select id from auth.users where email = 'VOTRE_EMAIL_ADMIN'
     on conflict (user_id) do nothing;
     ```
   - Cliquez **"Run"**.
   - **Pourquoi c'est obligatoire** : depuis cette mise à jour, un compte
     "connecté" ne suffit plus pour accéder à `admin.html` — il faut aussi
     figurer dans cette table. Sans cette étape, même votre propre compte
     admin perdra l'accès aux annonces en attente.

10. Récupérez vos clés API :
    - Allez dans **"Project Settings" (roue dentée) → "API"**.
    - Dans l'onglet **"Data API"**, copiez la valeur **"Project URL"**
      (ex. `https://abcdefgh.supabase.co` — **sans** `/rest/v1/` à la fin).
    - Dans l'onglet **"API Keys"**, copiez la clé **"anon"** / **"publishable"**
      (jamais la clé `service_role`).
    - Gardez ces deux valeurs sous la main pour la Partie 2.

---

## Partie 2 — Connecter les fichiers du site

Ouvrez chacun des quatre fichiers `kaypam.html`, `publier.html`,
`admin.html` et `mes-annonces.html` dans un éditeur de texte (Bloc-notes,
VS Code, etc.). Tout en haut du `<script>`, vous verrez :

```js
const SUPABASE_URL = "VOTRE_SUPABASE_URL";
const SUPABASE_ANON_KEY = "VOTRE_SUPABASE_ANON_KEY";
```

Remplacez ces deux valeurs par celles copiées à l'étape 8 ci-dessus, **dans
les quatre fichiers**. Exemple :

```js
const SUPABASE_URL = "https://abcdefgh.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";
```

Dans `mes-annonces.html` uniquement, remplacez aussi votre numéro MonCash
Business (celui qui recevra les paiements de boost) :

```js
const MONCASH_NUMBER = "+509 0000 0000";
```

Enregistrez les quatre fichiers.

---

## Partie 3 — Mettre le site en ligne (Netlify, gratuit)

1. Allez sur **https://app.netlify.com/drop**.
2. Glissez-déposez le dossier contenant vos 5 fichiers
   (`kaypam.html`, `publier.html`, `admin.html`, `mes-annonces.html`, et si
   vous en avez un, un fichier `index.html` qui redirige vers `kaypam.html`)
   directement sur la page.
3. Netlify publie le site en quelques secondes et vous donne une adresse du
   type `https://random-name-123.netlify.app`.
4. Dans le tableau de bord Netlify, vous pouvez renommer ce sous-domaine
   gratuitement (**"Site settings" → "Change site name"**), par exemple
   `kaypam.netlify.app`.

### Nom de domaine personnalisé (optionnel, payant)

Si vous voulez `kaypam.ht` ou `kaypam.com` plutôt qu'une adresse
`.netlify.app` :
1. Achetez le nom de domaine chez un registrar (Namecheap, Google Domains,
   etc. — environ 10-20 USD/an selon l'extension).
2. Dans Netlify, allez dans **"Domain settings" → "Add a domain"** et suivez
   les instructions pour connecter votre domaine.

---

## Partie 4 — Tester le parcours complet

1. Ouvrez votre site en ligne (`kaypam.html`).
2. Cliquez **"Publier gratuitement"**. Onglet **"Créer un compte"** :
   choisissez un nom d'utilisateur test, un mot de passe, votre nom et
   téléphone, puis **"Créer mon compte"** — vous devez arriver directement
   sur le formulaire de publication (pas de re-connexion demandée).
3. Remplissez le formulaire avec une annonce test, ajoutez une photo,
   soumettez.
4. Ouvrez `admin.html`, connectez-vous avec l'email/mot de passe admin créé
   à l'étape 7 de la Partie 1. Vous devriez voir votre annonce test en
   attente, avec la vraie photo affichée.
5. Cliquez **"✅ Valider"**.
6. Retournez sur `kaypam.html` et rafraîchissez la page — votre annonce
   test doit maintenant apparaître dans la liste publique avec sa vraie
   photo et le vrai bouton WhatsApp.
7. Ouvrez `mes-annonces.html`, connectez-vous avec le **même compte
   propriétaire test** créé à l'étape 2 (onglet "Se connecter"), cliquez
   **"⭐ Booster cette annonce"**, choisissez un plan, entrez n'importe
   quelle référence (c'est un test), et confirmez.
8. Retournez dans `admin.html`, descendez jusqu'à **"Demandes de boost"** —
   votre demande doit apparaître **"En attente"**. Cliquez
   **"✅ Confirmer paiement & activer"**.
9. Retournez sur `kaypam.html` et rafraîchissez — le bandeau
   **"⭐ Annonces boostées"** doit maintenant apparaître en haut de la page,
   avant même les filtres, avec votre annonce test dedans.
10. Retournez sur `mes-annonces.html` (déjà connecté), cliquez
    **"🚫 Bien plus disponible — retirer l'annonce"** — l'annonce doit
    disparaître de `kaypam.html` après rafraîchissement, et son boost doit
    passer à "Expiré" dans `admin.html`.

Si tout fonctionne, votre backend réel avec comptes propriétaires est
opérationnel.

---

## Comment fonctionne le roulement des annonces boostées

- Le bandeau affiche jusqu'à **10 annonces boostées** à la fois.
- S'il y a 10 boosts actifs ou moins, elles restent toutes affichées sans
  interruption.
- S'il y en a plus de 10, un **nouveau lot de 10** apparaît automatiquement
  toutes les **45 secondes**, en boucle continue (le 3ᵉ lot peut redonner
  le 1ᵉʳ lot si le total n'est pas un multiple de 10).
- Un boost expire automatiquement à la date de fin — aucune tâche
  planifiée n'est nécessaire, c'est la base de données elle-même qui arrête
  de le montrer dès que sa fenêtre de temps est dépassée.
- Les 3 formules par défaut (7 jours/10 $, 14 jours/18 $, 30 jours/30 $)
  sont modifiables directement dans Supabase : **Table Editor → boost_plans**.

---

## Limites de la formule gratuite (à connaître)

- **Taille des fichiers** : le formulaire limite déjà chaque photo à 15 Mo (compressée
  automatiquement avant l'envoi, donc le fichier réel envoyé est bien plus léger)
  et chaque vidéo à 50 Mo — cette limite vidéo correspond exactement à la limite
  par défaut d'un bucket Supabase gratuit. Si vous l'augmentez côté Supabase
  (Storage → bucket → "File size limit"), pensez à augmenter aussi `MAX_VIDEO_MB`
  dans `publier.html` pour que les deux restent alignés.
- **Supabase gratuit** : 500 Mo de base de données, 1 Go de stockage
  fichiers, projet mis en pause après 7 jours d'inactivité (se réactive
  automatiquement au premier visiteur, avec quelques secondes de délai).
  Largement suffisant pour démarrer et valider votre marché.
- **Netlify gratuit** : 100 Go de bande passante/mois — suffisant pour
  plusieurs dizaines de milliers de visites.
- Quand KayPam grandira (des centaines d'annonces avec photos/vidéos), il
  faudra passer aux formules payantes de Supabase (à partir de 25 USD/mois)
  et compresser les vidéos avant envoi pour économiser l'espace de stockage.

## Prochaines améliorations recommandées

- Ajouter un second compte admin si vous prenez un associé pour la
  vérification des annonces (Authentication → Users → Add user).
- Envisager MonCash pour le modèle "Annonces Vedettes" évoqué précédemment,
  une fois le trafic organique établi.
