# Voice Input: "error_network, permanent: true" - ROOT CAUSE ANALYSIS

**Ngày:** 17/12/2025  
**Lỗi:** `SpeechRecognitionError msg: error_network, permanent: true`  
**Status:** ANALYSIS ONLY - NO CODE MODIFICATIONS

---

## 🔴 ROOT CAUSE: Missing RECORD_AUDIO Permission Request

```
I/flutter ( 6750): [VoiceController] ✅ Started listening...
I/flutter ( 6750): [VoiceController] 🔵 Speech status: listening
I/flutter ( 6750): [VoiceController] ✅ Started listening
I/flutter ( 6750): [VoiceController] 🔵 Speech status: notListening
I/flutter ( 6750): [VoiceController] 🔵 Speech status: done
I/flutter ( 6750): [VoiceController] ❌ Speech recognition error: SpeechRecognitionError msg: error_network, permanent: true
```

**Chi tiết vấn đề:**

1. ✅ RECORD_AUDIO permission có trong AndroidManifest.xml
2. ✅ speech_to_text plugin được cài đặt
3. ✅ VoiceController.startListening() gọi \_speech.listen()
4. ❌ **KHÔNG CÓ** `requestPermission()` call trước khi gọi `_speech.listen()`
5. ❌ Kết quả: Android từ chối voice input (permanent error)

---

## 📍 Vị trí Code

### File: `lib/features/voice_input/presentation/controllers/voice_controller.dart`

**Lines 94-132: `_initializeSpeech()` method**

```dart
Future<void> _initializeSpeech() async {
  if (_isInitialized) return;

  try {
    final available = await _speech.initialize(
      onError: (error) {
        debugPrint('[VoiceController] ❌ Speech recognition error: SpeechRecognitionError msg: ${error.errorMsg}, permanent: ${error.permanent}');
        state = state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Speech recognition error: ${error.errorMsg}',
        );
      },
      onStatus: (status) {
        debugPrint('[VoiceController] 🔵 Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (state.status == VoiceStatus.listening) {
            state = state.copyWith(status: VoiceStatus.idle);
          }
        }
      },
    );
    // ... rest of code
  }
}
```

**Lines 140-191: `startListening()` method**

```dart
Future<void> startListening({void Function(RecognizedFood food)? onFoodRecognized}) async {
  if (!_isInitialized) {
    await _initializeSpeech();
    if (!_isInitialized) {
      debugPrint('[VoiceController] ❌ Cannot start listening: speech not initialized');
      return;
    }
  }

  if (state.status == VoiceStatus.listening || state.status == VoiceStatus.processing) {
    debugPrint('[VoiceController] ⚠️ Already listening or processing');
    return;
  }

  try {
    debugPrint('[VoiceController] 🔵 Starting listening...');

    state = state.copyWith(
      status: VoiceStatus.listening,
      errorMessage: null,
      clearError: true,
      clearTranscript: true,
      clearFinalTranscript: true,
      clearRecognizedFood: true,
      clearSuggestions: true,
    );

    // ❌ PROBLEM: No permission request before calling _speech.listen()
    await _speech.listen(
      onResult: (result) {
        debugPrint('[VoiceController] 🔵 Speech result: ${result.recognizedWords}');
        state = state.copyWith(currentTranscript: result.recognizedWords);

        if (result.finalResult) {
          final finalTranscript = result.recognizedWords;
          debugPrint('[VoiceController] ✅ Final transcript: $finalTranscript');
          state = state.copyWith(
            transcript: finalTranscript,
            currentTranscript: finalTranscript,
          );
          processCurrentTranscript();
        }
      },
      localeId: 'vi_VN',  // ← Vietnamese locale
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
      ),
    );

    debugPrint('[VoiceController] ✅ Started listening');
    _onFoodRecognizedCallback = onFoodRecognized;
  } catch (e, stackTrace) {
    // ... error handling
  }
}
```

---

## ❌ What's Wrong

### Current Flow:

```
User taps Voice Input Button
    ↓
controller.startListening()
    ↓
_isInitialized check (true if _initializeSpeech ran before)
    ↓
_speech.listen(localeId: 'vi_VN')  ← ❌ NO PERMISSION REQUEST!
    ↓
Android: "You want to record audio? I didn't get permission!"
    ↓
error_network (permanent: true)  ← Can't retry because permission wasn't granted
```

### Problem Details:

1. **`_initializeSpeech()` doesn't request permission**

   - Only calls `_speech.initialize()`
   - This checks if speech recognition is available, NOT if we have permission
   - Manifest declares permission, but doesn't grant it at runtime

2. **Android 6.0+ requires runtime permission**

   - `RECORD_AUDIO` must be declared in AndroidManifest.xml ✅ Done
   - `RECORD_AUDIO` must be granted at runtime via permission_handler ❌ **NOT DONE**

3. **No permission request before `_speech.listen()`**

   - `startListening()` directly calls `_speech.listen()`
   - speech_to_text will fail with error_network if permission not granted
   - Called "permanent: true" because Android outright denies without permission

4. **speech_to_text library behavior**
   - `SpeechToText.initialize()` = check availability, NOT permission
   - `SpeechToText.listen()` = start listening, requires permission
   - Error only appears when calling `listen()`, not `initialize()`

---

## 📊 Comparison: Current vs Correct

### ❌ Current (WRONG):

```dart
_initializeSpeech()  → _speech.initialize()  (no permission check)
    ↓
startListening()  → _speech.listen()  (fails: permission denied)
    ↓
Error: error_network (permanent: true)
```

### ✅ Correct (REQUIRED):

```dart
_initializeSpeech()  → [Request RECORD_AUDIO permission]
                    → _speech.initialize()

startListening()  → [Check permission granted]
                 → _speech.listen()  (works!)
                 ↓
                 Success
```

---

## 📋 Technical Details

### Android Runtime Permissions:

```
Manifest Declaration:
  └─ <uses-permission android:name="android.permission.RECORD_AUDIO" />
     ✅ Declared in android/app/src/main/AndroidManifest.xml (Line 18)

Runtime Request:
  └─ Need to call permission_handler to REQUEST at runtime
     ❌ NOT called anywhere in VoiceController
     ❌ Permission never granted to app
```

### speech_to_text Behavior:

```dart
// ✅ This only checks if feature available
final available = await _speech.initialize(
  onError: (error) { ... },
  onStatus: (status) { ... },
);

// ❌ This requires RECORD_AUDIO permission at runtime
// If permission not granted → error_network (permanent: true)
await _speech.listen(
  onResult: (result) { ... },
  localeId: 'vi_VN',
);
```

---

## 🔍 Why "permanent: true"?

```
When Android denies permission (never granted):
  → speech_to_text returns error_network (permanent: true)

Meaning:
  - "This error won't go away by retrying"
  - "It's a permanent state because permission is denied"
  - "The user needs to grant permission in Settings"
  - OR "The developer needs to request permission programmatically"
```

---

## 🎯 Solution Requirements

### Must Do:

1. **Before calling `_speech.listen()`:**

   - Request `Permission.microphone` using permission_handler
   - Wait for permission to be granted
   - Only then proceed with `_speech.listen()`

2. **In `_initializeSpeech()` OR `startListening()`:**
   - Add permission request logic
   - Check if permission granted
   - Handle permission denied case

### Implementation Locations:

**Option 1: Request in `_initializeSpeech()` (RECOMMENDED)**

- Request permission once during initialization
- If denied, mark state as error
- Prevents repeated permission requests

**Option 2: Request in `startListening()`**

- Request permission each time user taps button
- User can grant/deny each time
- More flexible but more prompts

**Option 3: Request in UI layer (VoiceInputButton)**

- Request before calling startListening()
- UI has control over permission flow
- Separates concerns

---

## 📝 Code Changes Needed

### Import permission_handler:

```dart
import 'package:permission_handler/permission_handler.dart' as ph;
```

### Add permission request method:

```dart
Future<bool> _requestRecordAudioPermission() async {
  final status = await ph.Permission.microphone.request();

  if (status.isDenied) {
    debugPrint('[VoiceController] ⚠️ Microphone permission denied by user');
    return false;
  } else if (status.isPermanentlyDenied) {
    debugPrint('[VoiceController] ❌ Microphone permission permanently denied - open app settings');
    return false;
  } else if (status.isGranted) {
    debugPrint('[VoiceController] ✅ Microphone permission granted');
    return true;
  }

  return false;
}
```

### Update `startListening()`:

```dart
Future<void> startListening({void Function(RecognizedFood food)? onFoodRecognized}) async {
  // 1. Check/request permission FIRST
  final hasPermission = await _requestRecordAudioPermission();
  if (!hasPermission) {
    state = state.copyWith(
      status: VoiceStatus.error,
      errorMessage: 'Cần quyền truy cập microphone. Vui lòng cấp quyền trong Cài đặt.',
    );
    return;
  }

  // 2. Then initialize if needed
  if (!_isInitialized) {
    await _initializeSpeech();
    if (!_isInitialized) {
      debugPrint('[VoiceController] ❌ Cannot start listening: speech not initialized');
      return;
    }
  }

  // 3. Rest of code continues...
  if (state.status == VoiceStatus.listening || state.status == VoiceStatus.processing) {
    debugPrint('[VoiceController] ⚠️ Already listening or processing');
    return;
  }

  try {
    debugPrint('[VoiceController] 🔵 Starting listening...');
    state = state.copyWith(
      status: VoiceStatus.listening,
      errorMessage: null,
      clearError: true,
      clearTranscript: true,
      clearFinalTranscript: true,
      clearRecognizedFood: true,
      clearSuggestions: true,
    );

    // 4. Now listen (permission guaranteed)
    await _speech.listen(
      onResult: (result) {
        // ... rest unchanged
      },
      localeId: 'vi_VN',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
      ),
    );
    // ...
  }
}
```

---

## 🚨 Key Insight

### The Error Message Tells The Story:

```
error_network, permanent: true
├─ error_network    = "I can't record audio (network/device issue)"
└─ permanent: true  = "This won't change - permission is denied at OS level"
```

This is Android's way of saying:

- "App doesn't have RECORD_AUDIO permission"
- "Can't fix by retrying the same code"
- "Need permission grant or app reinstall"

---

## ✅ Checklist to Fix

- [ ] Import `permission_handler`
- [ ] Add `_requestRecordAudioPermission()` method
- [ ] Update `startListening()` to request permission first
- [ ] Handle permission denied case gracefully
- [ ] Test: Grant permission → voice input works
- [ ] Test: Deny permission → proper error message
- [ ] Test: Revoke permission in Settings → app requests again on next use

---

## 📌 Summary

| Aspect                           | Status         | Detail                                                      |
| -------------------------------- | -------------- | ----------------------------------------------------------- |
| Permission declared              | ✅ OK          | AndroidManifest.xml has RECORD_AUDIO                        |
| Permission requested at runtime  | ❌ **MISSING** | VoiceController never calls permission_handler              |
| Permission checked before listen | ❌ **MISSING** | startListening() calls \_speech.listen() without permission |
| Error handling                   | ⚠️ Partial     | Catches error but doesn't prompt for permission             |
| User messaging                   | ⚠️ Partial     | Shows generic error, not specific permission error          |

**Root Cause:** VoiceController initializes speech recognition but never requests RECORD_AUDIO permission at runtime. When user tries to listen, Android denies access (permanent: true).

**Solution:** Add permission request in `_initializeSpeech()` or `startListening()` before calling `_speech.listen()`.
