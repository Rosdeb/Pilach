# Two-Factor Authentication (2FA) Implementation Plan

This plan outlines a production-ready, beautiful, and secure Two-Factor Authentication (2FA) system using `dio` and `flutter_riverpod`, built on top of the existing `ApiService` and `AuthRepository`.

---

## 🏛️ Architecture: Dedicated Verification Screen vs. Inlined Widget

We recommend utilizing a **separate verification screen** (`TwoFactorVerifyScreen`) instead of inline input:
- **High Reusability:** The verification screen can be reused for login challenges (`/challenge/verify`), email confirmation, SMS confirmation, or authorizing sensitive actions (e.g., password change or account deletion).
- **Separation of Concerns:** Keep the primary Login Screen simple. The OTP flow gets its own dedicated layout, logic, and state lifecycle.
- **Navigation Safety:** Fits seamlessly in a GoRouter scheme with deep-link support.

---

## 📂 Proposed Folder Structure

```text
lib/
 └── Features/
      ├── auth/
      │    ├── data/repositories/
      │    │    └── auth_repository.dart       # Enhanced with 2FA calls
      │    └── presentation/
      │         └── screens/
      │              └── two_factor_verify_screen.dart   # Dedicated code verification
      └── Me/
           └── presentation/
                ├── providers/
                │    └── two_factor_provider.dart        # Manages enrolled methods & states
                └── screens/
                     └── security_privacy/
                          ├── security_privacy_screen.dart   # Updates switch to navigation row
                          └── two_factor_settings_screen.dart # 2FA management (Email/SMS toggle)
```

---

## 🔌 API Endpoints Reference

### 1. Enrollment (Settings Page)
- **Email:**
  - `POST /api/v1/auth/2fa/enroll/email/request` (starts enrollment, sends code)
  - `POST /api/v1/auth/2fa/enroll/email/confirm` `{"code": "760115"}` (completes enrollment)
- **SMS:**
  - `POST /api/v1/auth/2fa/enroll/sms/request` `{"phone": "string"}` (starts enrollment, sends code)
  - `POST /api/v1/auth/2fa/enroll/sms/confirm` `{"code": "04841356"}` (completes enrollment)
- **Management:**
  - `GET /api/v1/auth/2fa/methods` (list enrolled methods)
  - `DELETE /api/v1/auth/2fa/methods/{methodId}` (disable a method)

### 2. Login Challenge (Authentication Page)
- `POST /api/v1/auth/2fa/challenge/send` (sends a code for verification challenge)
- `POST /api/v1/auth/2fa/challenge/verify` `{"code": "..."}` (verifies challenge and returns session tokens)

---

## 🔄 Sequence Flows

### A. Settings 2FA Enrollment (Email or SMS)
1. **User Settings Tap:** User opens `TwoFactorSettingsScreen` (under Security & Privacy) and taps on **Email** or **SMS** authentication.
2. **Send OTP Code Request:**
   - For email: Request OTP via `/2fa/enroll/email/request`.
   - For SMS: Prompts for phone number, then requests OTP via `/2fa/enroll/sms/request`.
3. **Verify:** Navigate to `TwoFactorVerifyScreen` passing enrollment details (method type, destination details).
4. **Confirm Code:** User inputs code. Screen calls `/2fa/enroll/email/confirm` or `/2fa/enroll/sms/confirm`.
5. **Enrolled:** Go back to `TwoFactorSettingsScreen` and refresh the list of active methods.

### B. Login Challenge (With Auto-Refresh Handler)
1. **Primary Authentication:** User enters credentials on `LoginScreen`.
2. **2FA Challenge Check:** If response indicates 2FA is required, the app stores the temporary session and redirects the user to `TwoFactorVerifyScreen` (Login mode).
3. **Challenge Verify:** User enters the code, verifying it via `/2fa/challenge/verify`. Upon success, the app saves access and refresh tokens, shifting state to authenticated.

---

## 🛠️ Step-by-Step Implementation Detail

### Step 1: Update API Constants
Add 2FA endpoints to `lib/core/constants/api_constants.dart`:
```dart
  static const String twoFactorMethods = "/api/v1/auth/2fa/methods";
  static const String twoFactorEnrollEmailRequest = "/api/v1/auth/2fa/enroll/email/request";
  static const String twoFactorEnrollEmailConfirm = "/api/v1/auth/2fa/enroll/email/confirm";
  static const String twoFactorEnrollSmsRequest = "/api/v1/auth/2fa/enroll/sms/request";
  static const String twoFactorEnrollSmsConfirm = "/api/v1/auth/2fa/enroll/sms/confirm";
  static const String twoFactorChallengeSend = "/api/v1/auth/2fa/challenge/send";
  static const String twoFactorChallengeVerify = "/api/v1/auth/2fa/challenge/verify";
  static String twoFactorDisableMethod(String methodId) => "/api/v1/auth/2fa/methods/$methodId";
```

### Step 2: Implement AuthRepository Enhancements
Implement methods in [auth_repository.dart](file:///Users/rosdeb/BuisnessBuild/MessageApp/lib/Features/auth/data/repositories/auth_repository.dart) to wrap the backend API calls. Ensure proper extraction of cookie/header data as specified in `plan/implement`.

### Step 3: Implement Riverpod Providers
Create `TwoFactorState` containing:
- `List<dynamic> enrolledMethods`
- `bool isLoading`
- `String? errorMessage`
Create `twoFactorNotifierProvider` to orchestrate fetches, requests, confirmations, and deletions.

### Step 4: Create Interfaces with Premium Aesthetics
1. **`TwoFactorSettingsScreen`:** Toggle switches for "Email Verification" and "SMS Verification", reflecting actual enrolled states. Includes interactive enrollment dialogs for SMS/phone number input.
2. **`TwoFactorVerifyScreen`:** Clean, centered typography and animated bottom-cursor inputs (`Pinput` package) fully matching light/dark system settings.
3. **`SecurityPrivacyScreen` Integration:** Replace the simple boolean toggle switch row for "Two-Factor Auth" with a navigation row leading to `TwoFactorSettingsScreen`.
