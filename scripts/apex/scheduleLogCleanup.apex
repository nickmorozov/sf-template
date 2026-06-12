// Schedule the Log Cleanup batch to run daily at 2:00 AM.
// Run this script once per org after deployment:
//   sf apex run --file scripts/apex/scheduleLogCleanup.apex
System.schedule('Log Cleanup', '0 0 2 * * ?', new LogCleanupSchedulable());
System.debug('Log cleanup scheduled for daily 2:00 AM execution.');
