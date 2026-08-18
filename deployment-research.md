# Free deployment assessment

Render's official free-tier documentation states that free web services support web apps in Node.js and provide 750 free instance hours per workspace per calendar month. Free services spin down on idle and have an ephemeral filesystem; local SQLite databases and uploaded files are lost when the service redeploys, restarts, or spins down. Render explicitly says the free tier is not for production applications.

Vercel's official SQLite guidance states that SQLite cannot be used for permanent writes in its serverless environment because the filesystem is ephemeral and concurrent function instances do not share local storage. Vercel therefore requires an external storage/database solution for this application's data.

Decision implication: Render Free can host the current Express app as a public demo, but the current SQLite data is not durable there. A durable no-cost deployment requires refactoring the database layer to a hosted database such as a free-tier external SQLite/Postgres service and supplying its credentials, then deploying the backend to a compatible host.

## Flutter web deployment references

Official Flutter documentation confirms that the stable SDK can be installed manually and that production web output is generated with `flutter build web` into the build directory. The Vercel deployment will therefore use a static output directory after building the Flutter client, while the existing Express backend remains a separate API/runtime concern.

References:

- https://docs.flutter.dev/install
- https://docs.flutter.dev/install/manual
- https://docs.flutter.dev/deployment/web
