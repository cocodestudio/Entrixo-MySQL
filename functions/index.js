const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

setGlobalOptions({ region: "asia-south1" });

exports.sendAttendanceNotification = onDocumentCreated("attendance/{attendanceId}", async (event) => {
    const data = event.data.data();
    const uid = data.uid;

    try {
        const userDoc = await admin.firestore().collection("users").doc(uid).get();
        
        if (!userDoc.exists) {
            console.log("User not found");
            return null;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        const userName = userData.name || "Student";

        if (!fcmToken) {
            console.log("No FCM Token found for user:", uid);
            return null;
        }

        const title = "Attendance Marked! ✅";
        const body = `Hey ${userName}, your attendance for the session has been successfully recorded.`;

        const message = {
            notification: {
                title: title,
                body: body,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                type: "attendance",
                status: "success"
            },
            token: fcmToken,
        };

        const response = await admin.messaging().send(message);
        console.log("Successfully sent message:", response);
        await admin.firestore().collection("notifications").add({
            uid: uid,
            title: title,
            message: body,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            type: "attendance_success",
            icon: "check_circle"
        });

        return null;
    } catch (error) {
        console.error("Error sending notification:", error);
        return null;
    }
});

exports.notifyNewResource = onDocumentCreated("resources/{resourceId}", async (event) => {
    const data = event.data.data();
    const type = data.type;
    const title = data.title;
    const courseId = data.courseId;
    const semester = data.semester;

    try {
        const db = admin.firestore();
        let studentQuery = db.collection("users").where("role", "==", "student");
        if (courseId !== "ALL") {
            studentQuery = studentQuery.where("courseId", "==", courseId);
            if (semester !== "ALL") {
                studentQuery = studentQuery.where("currentSemester", "==", parseInt(semester));
            }
        }

        const snapshot = await studentQuery.get();

        if (snapshot.empty) {
            console.log("No matching students found for this resource.");
            return null;
        }

        const notifTitle = type === "Assignment" ? "New Assignment Uploaded! 📝" : "New Resource Available! 📚";
        const notifBody = `${title} has been posted for ${data.courseName}. Check it out now!`;
        const iconName = type === "Assignment" ? "assignment_turned_in" : "folder_copy";

        const tokens = [];
        const notificationPromises = [];

        snapshot.forEach(doc => {
            const studentData = doc.data();
            if (studentData.fcmToken) {
                tokens.push(studentData.fcmToken);
                notificationPromises.push(
                    db.collection("notifications").add({
                        uid: doc.id,
                        title: notifTitle,
                        message: notifBody,
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        isRead: false,
                        type: type.toLowerCase(),
                        icon: iconName
                    })
                );
            }
        });

        if (tokens.length === 0) return null;

        const message = {
            notification: {
                title: notifTitle,
                body: notifBody,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                type: type.toLowerCase(),
                courseId: courseId
            },
            tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`${response.successCount} notifications sent successfully.`);
        await Promise.all(notificationPromises);

        return null;
    } catch (error) {
        console.error("Error sending resource notification:", error);
        return null;
    }
});

exports.notifyNewSession = onDocumentCreated("academic_sessions/{sessionId}", async (event) => {
    const data = event.data.data();
    const sessionName = data.sessionName;
    const courseId = data.courseId;
    const semester = data.targetSemester;
    const courseName = data.courseName;

    try {
        const db = admin.firestore();
        let studentQuery = db.collection("users").where("role", "==", "student");

        if (courseId !== "ALL") {
            studentQuery = studentQuery.where("courseId", "==", courseId);
            if (semester !== "ALL") {
                studentQuery = studentQuery.where("currentSemester", "==", parseInt(semester));
            }
        }

        const snapshot = await studentQuery.get();

        if (snapshot.empty) {
            console.log("No students found for this session criteria.");
            return null;
        }

        const notifTitle = "New Academic Session Active! 🗓️";
        const notifBody = courseId === "ALL"
            ? `The new session '${sessionName}' is now active for all courses.`
            : `New session '${sessionName}' is now active for ${courseName}${semester !== "ALL" ? " Sem " + semester : ""}.`;

        const tokens = [];
        const notificationPromises = [];

        snapshot.forEach(doc => {
            const studentData = doc.data();
            if (studentData.fcmToken) {
                tokens.push(studentData.fcmToken);
                notificationPromises.push(
                    db.collection("notifications").add({
                        uid: doc.id,
                        title: notifTitle,
                        message: notifBody,
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        isRead: false,
                        type: "session_update",
                        icon: "event_available"
                    })
                );
            }
        });

        if (tokens.length === 0) return null;

        const message = {
            notification: {
                title: notifTitle,
                body: notifBody,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                type: "session",
                sessionId: event.params.sessionId
            },
            tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Session notification sent to ${response.successCount} students.`);

        await Promise.all(notificationPromises);
        return null;

    } catch (error) {
        console.error("Error sending session notification:", error);
        return null;
    }
});