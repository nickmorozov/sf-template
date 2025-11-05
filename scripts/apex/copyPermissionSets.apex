// Copy missing Permission Sets + Permission Set Groups from one user to another
// Replace these with your source/target identifiers
String SOURCE = 'llima@corraogroup.com.bftpm3';
String TARGET = 'jonathan_castelo@b-f.com.bftpm3';

List<User> u = [
    SELECT Id, Username, Email
    FROM User
    WHERE Username IN :new List<String>{ SOURCE, TARGET }
    ORDER BY IsActive DESC
    LIMIT 2
];

if (u.size() < 2) {
    String username = (u.isEmpty() ? SOURCE + ' and ' + TARGET : (u.size() == 1 && u[0].Username == SOURCE) ? TARGET : SOURCE);
    System.debug(LoggingLevel.ERROR, 'Username not found: ' + username);
    return;
}

User src = u[0].Username == SOURCE ? u[0] : u[1];
User dst = u[0].Username == TARGET ? u[0] : u[1];

// --- Permission Sets ---
Set<Id> srcPsIds = new Set<Id>();
Map<Id, PermissionSet> srcPsById = new Map<Id, PermissionSet>(
    [
        SELECT Id, Name, Label, IsOwnedByProfile, LicenseId
        FROM PermissionSet
        WHERE Id IN (SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :src.Id)
    ]
);
for (PermissionSet ps : srcPsById.values()) {
    if (!ps.IsOwnedByProfile)
        srcPsIds.add(ps.Id); // skip profile “permission sets”
}

Set<Id> dstPsIds = new Set<Id>();
for (PermissionSetAssignment psa : [SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :dst.Id]) {
    dstPsIds.add(psa.PermissionSetId);
}

List<PermissionSetAssignment> toInsertPSA = new List<PermissionSetAssignment>();
for (Id psId : srcPsIds) {
    if (!dstPsIds.contains(psId)) {
        toInsertPSA.add(new PermissionSetAssignment(AssigneeId = dst.Id, PermissionSetId = psId));
    }
}

// --- DML with error reporting ---
Integer psSuccess = 0, psgSuccess = 0;
List<String> psAdded = new List<String>();
List<String> errors = new List<String>();

// Insert Permission Sets
if (!toInsertPSA.isEmpty()) {
    Database.SaveResult[] r = Database.insert(toInsertPSA, /*allOrNone*/ false);
    for (Integer i = 0; i < r.size(); i++) {
        if (r[i].isSuccess()) {
            psSuccess++;
            Id psId = toInsertPSA[i].PermissionSetId;
            psAdded.add(srcPsById.containsKey(psId) ? srcPsById.get(psId).Label : String.valueOf(psId));
        } else {
            for (Database.Error e : r[i].getErrors()) {
                errors.add('PS [' + toInsertPSA[i].PermissionSetId + ']: ' + e.getMessage());
            }
        }
    }
}

// --- Summary ---
System.debug(LoggingLevel.INFO, 'Copied from: ' + src.Username + '  ->  to: ' + dst.Username);
System.debug(LoggingLevel.INFO, 'Permission Sets added: ' + psSuccess + ' ' + psAdded);
if (!errors.isEmpty()) {
    System.debug(LoggingLevel.WARN, 'Some assignments failed:\n - ' + String.join(errors, '\n - '));
}