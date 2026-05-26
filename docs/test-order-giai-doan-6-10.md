# TEST ORDER GIAI DOAN 6 -> 10

Cap nhat: 2026-04-09

Muc tieu: di theo mot thu tu test duy nhat, tu smoke -> regression -> security -> release gate.

## 0) Chuan bi (5 phut)
- [ ] Pull code moi nhat va chay voi env giong khi dev.
- [ ] Dam bao co 3 tai khoan test: `A`, `B`, `C`.
- [ ] Neu test security, bat them Firebase Emulator Suite.

## 1) Gate ky thuat nhanh (5-10 phut)
- [ ] `flutter gen-l10n`
- [ ] `flutter analyze`
- [ ] `flutter test`

Neu fail o buoc nay: dung test manual, fix compile/test truoc.

## 2) Smoke flow (10-15 phut)
- [ ] First-run: app mo `Onboarding` (chi 1 lan), bo qua/hoan tat -> vao login.
- [ ] Dang nhap thanh cong -> vao Home.
- [ ] Mo duoc cac tab: Chat, Groups, Contacts, Profile.
- [ ] Tao nhom co avatar tu gallery, vao chat nhom thanh cong.
- [ ] Trong chat nhom, mo duoc `GroupInfo` tu app bar.

## 3) Regression GĐ6 (on dinh) (15-20 phut)
Thuc hien theo file:
- [ ] `docs/regression-giai-doan-6.md`

Trong tam:
- chat 1-1 gui text/anh + retry khi loi mang
- add friend send/accept/reject/cancel
- create group + retry

## 4) Regression GĐ8 (search/pin/unread) (20-25 phut)
Thuc hien theo file:
- [ ] `docs/regression-giai-doan-8.md`

Trong tam:
- search tin nhan 1-1 va nhom
- pin/unpin 1-1 va nhom (ca tu danh sach va GroupInfo)
- unread badge + dong bo read/unread
- regression gui/thu hoi/reply

## 5) Security GĐ9 (20-30 phut)
Thuc hien theo file:
- [ ] `docs/security-checklist-giai-doan-9.md`

Trong tam:
- user chi doc/ghi duoc du lieu thuoc quyen
- case DENY phai dung DENY (users/chat_rooms/groups + storage)
- luu log/screenshot cho cac case quan trong

## 6) Release gate GĐ10 (10 phut)
Thuc hien theo file:
- [ ] `docs/release-checklist-giai-doan-10.md`

Trong tam:
- xac nhan CI pass day du quality gate
- xac nhan artifact debug APK tao duoc va cai/chay duoc
- version/changelog dung voi release hien tai

## 7) Chot ket qua (5 phut)
- [ ] Danh dau PASS/FAIL cho tung muc 2 -> 6.
- [ ] Neu FAIL: ghi ro `buoc tai hien`, `tai khoan`, `man hinh`, `log`.
- [ ] Neu PASS toan bo: san sang chot release candidate.

---

## Thu tu khuyen nghi neu thieu thoi gian
1. Buoc 1 (gate ky thuat)
2. Buoc 2 (smoke flow)
3. Buoc 4 (GĐ8 regression)
4. Buoc 6 (release gate)
5. Buoc 3 + 5 khi co them thoi gian
