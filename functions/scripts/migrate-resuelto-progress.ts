/**
 * Migración puntual: Actualiza porcentajeAvance a 100 en todos los tickets
 * con status "Resuelto" que aún tengan un valor distinto de 100.
 *
 * Ejecutar desde /functions:
 *   npx tsx scripts/migrate-resuelto-progress.ts
 */
import { Firestore } from "@google-cloud/firestore";
import { execSync } from "child_process";

// Obtener access token de Firebase CLI
const token = execSync("firebase login:ci --no-localhost 2>nul || echo ''", {
  encoding: "utf-8",
}).trim();

// Conectar a Firestore con las credenciales del proyecto
const db = new Firestore({
  projectId: "astro-b97c2",
});

async function main() {
  const snap = await db
    .collection("Incidentes")
    .where("status", "==", "Resuelto")
    .get();

  console.log(`Tickets en "Resuelto" encontrados: ${snap.size}`);

  let updated = 0;
  const batch = db.batch();

  for (const doc of snap.docs) {
    const data = doc.data();
    const current = typeof data.porcentajeAvance === "number"
      ? data.porcentajeAvance
      : 0;

    if (current !== 100) {
      batch.update(doc.ref, { porcentajeAvance: 100 });
      updated++;
      console.log(
        `  → ${doc.id}: "${data.titulo ?? "sin título"}" (${current}% → 100%)`
      );
    }
  }

  if (updated > 0) {
    await batch.commit();
    console.log(`\n✓ ${updated} ticket(s) actualizados a 100%.`);
  } else {
    console.log("\n✓ Todos los tickets Resuelto ya tienen 100%.");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Error:", err);
  process.exit(1);
});
