import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Inicializa la conexión con privilegios de administrador
admin.initializeApp();
const db = admin.firestore();

// Esta es la función programada que se ejecutará cada 24 horas.
export const purgeOldLocations = onSchedule("every 24 hours", async () => {
  logger.info("Iniciando la purga de ubicaciones antiguas...");

  // 1. Obtener la política de retención global
  const configDoc = await db
    .collection("configuracion")
    .doc("politicaRetencionGlobal")
    .get();

  const maxDiasDeRetencion = configDoc.exists ?
    configDoc.data()?.maxDiasDeRetencion ?? 30 :
    30;

  logger.info(
    `Límite máximo de retención global: ${maxDiasDeRetencion} días.`
  );

  // 2. Obtener todos los usuarios
  const usersSnapshot = await db.collection("users").get();
  if (usersSnapshot.empty) {
    logger.info("No se encontraron usuarios. Finalizando la tarea.");
    return;
  }

  // 3. Procesar cada usuario
  const promises = usersSnapshot.docs.map(async (userDoc) => {
    const userData = userDoc.data();
    const userId = userDoc.id;

    const userRetentionDays = userData.diasDeRetencion ?? maxDiasDeRetencion;
    const effectiveRetentionDays = Math.min(
      userRetentionDays,
      maxDiasDeRetencion
    );

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - effectiveRetentionDays);

    logger.info(
      `Procesando usuario ${userId}. ` +
      `Retención: ${effectiveRetentionDays} días. ` +
      `Borrando antes de: ${cutoffDate.toISOString()}`
    );

    // 4. Buscar y borrar las ubicaciones antiguas para este usuario
    const oldLocationsQuery = db
      .collection("locations")
      .where("userId", "==", userId)
      .where("timestamp", "<", admin.firestore.Timestamp.fromDate(cutoffDate));

    return oldLocationsQuery.get().then((snapshot) => {
      if (snapshot.empty) {
        return Promise.resolve();
      }

      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      return batch.commit().then(() => {
        logger.info(
          `Se borraron ${snapshot.size} ubicaciones para el usuario ${userId}.`
        );
      });
    });
  });

  await Promise.all(promises);

  logger.info("Purga de ubicaciones completada con éxito.");
  return;
});
