# TaskFlow notification manual test checklist

Use a real iPhone/Android device or a simulator with notification support. Keep
the device date and timezone automatic unless a test asks you to change them.
Set every test due time relative to the device's current local time.

On Android, the app currently uses inexact alarms so delivery can be later than
the selected time. Android force-stop can also suppress scheduled alarms until
the app is opened again. iOS keeps at most 64 pending local notifications for
an app. These are operating-system limits, not app guarantees.

## Group A — Create a task

### A-01 — Reminder at the due time

- **Purpose:** Verify a new task schedules one reminder at its due time.
- **Before:** Notification permission is granted; TaskFlow notifications are on.
- **Steps:** Create “Test đúng hạn”, set due time to about 3 minutes from now,
  choose “Đúng giờ đến hạn”, save, then put TaskFlow in the background.
- **Expected:** One notification appears at the due time, with the task title
  and a due-now message.
- **Result:** ☐ Pass ☐ Fail

### A-02 — Reminder 15 minutes before

- **Purpose:** Verify the 15-minute offset.
- **Before:** Notifications are on and permitted.
- **Steps:** Create “Test trước 15 phút”, set due time about 17 minutes from now,
  choose “Trước 15 phút”, save, then background TaskFlow.
- **Expected:** One notification appears about 2 minutes from now, 15 minutes
  before the due time.
- **Result:** ☐ Pass ☐ Fail

### A-03 — Reminder one hour before

- **Purpose:** Verify the one-hour offset without waiting an hour.
- **Before:** Notifications are on and permitted.
- **Steps:** Create “Test trước 1 giờ”, set due time about 62 minutes from now,
  choose “Trước 1 giờ”, save, then background TaskFlow.
- **Expected:** One notification appears about 2 minutes from now, one hour
  before the due time.
- **Result:** ☐ Pass ☐ Fail

### A-04 — Reminder one day before

- **Purpose:** Verify the 24-hour offset without waiting a day.
- **Before:** Notifications are on and permitted.
- **Steps:** Create “Test trước 1 ngày”, set due time about 24 hours and 2 minutes
  from now, choose “Trước 1 ngày”, save, then background TaskFlow.
- **Expected:** One notification appears about 2 minutes from now, 24 hours
  before the due time.
- **Result:** ☐ Pass ☐ Fail

### A-05 — Task without a due date

- **Purpose:** Ensure a task without a due date does not get a reminder.
- **Before:** Notifications are on and permitted.
- **Steps:** Create “Test không hạn” without selecting a due date and save.
- **Expected:** The task is saved; no notification appears for it.
- **Result:** ☐ Pass ☐ Fail

### A-06 — “Không nhắc”

- **Purpose:** Ensure opting out never creates a reminder.
- **Before:** Notifications are on and permitted.
- **Steps:** Create “Test không nhắc”, set due time about 3 minutes from now,
  choose “Không nhắc”, save, then background TaskFlow.
- **Expected:** No notification appears at the due time.
- **Result:** ☐ Pass ☐ Fail

## Group B — Edit a task

### B-01 — Change the due time

- **Purpose:** Verify an edit replaces the old schedule.
- **Before:** Notifications are on and permitted.
- **Steps:** Create a task due about 4 minutes from now with “Đúng giờ đến hạn”.
  Edit it before the reminder time and move the due time about 5 minutes later.
- **Expected:** No notification appears at the old time; one appears at the new
  time. The task title is unchanged in the reminder.
- **Result:** ☐ Pass ☐ Fail

### B-02 — Change the reminder offset

- **Purpose:** Verify changing the reminder replaces the prior schedule.
- **Before:** Notifications are on and permitted.
- **Steps:** Create a task due about 20 minutes from now with “Trước 15 phút”.
  Edit it to “Đúng giờ đến hạn”.
- **Expected:** No notification appears at the old reminder time; one appears
  at the due time.
- **Result:** ☐ Pass ☐ Fail

### B-03 — Remove the due date

- **Purpose:** Ensure removing the due date cancels its reminder.
- **Before:** A future reminder is scheduled.
- **Steps:** Edit the task, tap “Xóa hạn”, and save.
- **Expected:** No notification appears at the former reminder time.
- **Result:** ☐ Pass ☐ Fail

### B-04 — Change to “Không nhắc”

- **Purpose:** Ensure opting out cancels the current schedule.
- **Before:** A future reminder is scheduled.
- **Steps:** Edit the task and choose “Không nhắc”. Save.
- **Expected:** No notification appears at the previous reminder time.
- **Result:** ☐ Pass ☐ Fail

## Group C — Completion and deletion

### C-01 — Complete a task before its reminder

- **Purpose:** Verify completion cancels a pending reminder.
- **Before:** A future reminder is scheduled.
- **Steps:** Mark the task complete before its reminder time.
- **Expected:** The task remains completed and no notification appears.
- **Result:** ☐ Pass ☐ Fail

### C-02 — Reopen a completed task

- **Purpose:** Verify an unfinished task is scheduled again.
- **Before:** TaskFlow notifications are on; the task's reminder time is still
  in the future.
- **Steps:** Mark the task complete, then mark it incomplete again.
- **Expected:** One reminder is scheduled again. It appears at its future time;
  it does not appear immediately if its reminder time has already passed.
- **Result:** ☐ Pass ☐ Fail

### C-03 — Delete a task

- **Purpose:** Verify deletion cancels only that task's reminder.
- **Before:** Two tasks have different future reminders.
- **Steps:** Delete one task and confirm the delete dialog. Keep the other task.
- **Expected:** The deleted task's reminder does not appear; the other task's
  reminder still appears.
- **Result:** ☐ Pass ☐ Fail

## Group D — App setting and OS permission

### D-01 — Turn app notifications off

- **Purpose:** Verify app-level off cancels pending reminders.
- **Before:** At least one future reminder is scheduled.
- **Steps:** In **Cá nhân → Thông báo**, turn the switch off.
- **Expected:** The switch shows off and pending TaskFlow reminders do not fire.
- **Result:** ☐ Pass ☐ Fail

### D-02 — Turn app notifications on with existing tasks

- **Purpose:** Verify enabling schedules current eligible tasks.
- **Before:** There is a future unfinished task with a reminder; OS permission is
  granted; app switch is off.
- **Steps:** Turn the switch on.
- **Expected:** The switch turns on after scheduling succeeds, and the task's
  reminder appears at its scheduled time.
- **Result:** ☐ Pass ☐ Fail

### D-03 — Deny OS permission

- **Purpose:** Verify denial does not leave the app switch on.
- **Before:** App switch is off and OS permission has not been granted.
- **Steps:** Turn the app switch on and deny the OS permission prompt.
- **Expected:** The switch remains off, TaskFlow explains that permission is
  needed, and “Mở cài đặt thông báo” is available.
- **Result:** ☐ Pass ☐ Fail

### D-04 — Grant permission from Settings

- **Purpose:** Verify TaskFlow rechecks permission after returning from Settings.
- **Before:** Permission was denied and the app switch is off.
- **Steps:** Use the in-app settings action, grant notifications in OS Settings,
  then return to TaskFlow. Turn the app switch on.
- **Expected:** The permission warning clears after returning; the app switch
  only turns on after the user enables it and scheduling succeeds.
- **Result:** ☐ Pass ☐ Fail

### D-05 — Revoke permission while app preference is on

- **Purpose:** Verify a permission change is detected on resume.
- **Before:** App switch is on and a reminder is scheduled.
- **Steps:** Revoke TaskFlow's OS permission in Settings, then return to the app.
- **Expected:** TaskFlow turns its switch off, shows a settings recovery action,
  and does not report notification setup as successful.
- **Result:** ☐ Pass ☐ Fail

## Group E — App lifecycle and notification tap

### E-01 — App in background

- **Purpose:** Verify the OS delivers a scheduled reminder without Flutter UI
  being visible.
- **Before:** A reminder is scheduled for about 3 minutes from now.
- **Steps:** Put TaskFlow in the background and wait.
- **Expected:** The OS displays the reminder at its scheduled time (Android may
  deliver an inexact alarm later).
- **Result:** ☐ Pass ☐ Fail

### E-02 — App closed and reopened

- **Purpose:** Verify scheduled reminders survive app closure and do not
  duplicate after task reload.
- **Before:** A future reminder is scheduled.
- **Steps:** Close TaskFlow normally, reopen it before the reminder time, then
  wait for the reminder.
- **Expected:** One reminder appears, not duplicate reminders.
- **Result:** ☐ Pass ☐ Fail

### E-03 — Tap a reminder

- **Purpose:** Verify the payload opens the correct task.
- **Before:** A task with a future reminder exists and the user is signed in.
- **Steps:** Tap its notification from the lock screen or notification center.
- **Expected:** TaskFlow opens that task's **Chi tiết công việc** screen.
- **Result:** ☐ Pass ☐ Fail

### E-04 — Device restart (Android)

- **Purpose:** Verify the plugin's boot receiver restores scheduled reminders.
- **Before:** A future reminder is scheduled.
- **Steps:** Restart the Android device, unlock it, and wait for the reminder.
- **Expected:** The reminder remains scheduled and appears once. OEM battery
  restrictions may affect delivery.
- **Result:** ☐ Pass ☐ Fail

## Group F — Time and timezone

### F-01 — Reminder time already passed

- **Purpose:** Ensure TaskFlow does not send a late notification immediately.
- **Before:** Notifications are on.
- **Steps:** Create a task whose due time is in the next few minutes but choose
  “Trước 15 phút”, making the calculated reminder time already past.
- **Expected:** No immediate notification is sent.
- **Result:** ☐ Pass ☐ Fail

### F-02 — Due time crosses midnight

- **Purpose:** Verify date arithmetic across a day boundary.
- **Before:** Notifications are on and permitted.
- **Steps:** Create a task due shortly after midnight and choose a reminder offset
  that still falls in the future. Background the app.
- **Expected:** One notification appears at the calculated local reminder time,
  on the correct date.
- **Result:** ☐ Pass ☐ Fail

### F-03 — Change device timezone

- **Purpose:** Verify timezone is read from the device and refreshed after app
  restart.
- **Before:** A task reminder is scheduled in the future.
- **Steps:** Change the device timezone, close and reopen TaskFlow, then inspect
  the task's due time and wait for its reminder.
- **Expected:** TaskFlow recalculates from the device timezone without an
  arbitrary UTC offset. Interpret the expected wall-clock time according to the
  task's stored instant.
- **Result:** ☐ Pass ☐ Fail
