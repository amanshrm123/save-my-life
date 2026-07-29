/// Shared avatar-card aspect ratio (design `home-avatars-v1.md` §2.3/§5.1) —
/// reused identically by `HomeAvatarCard` and the picker's `AvatarTile`
/// grid. One shared constant; the two call sites must never diverge.
const double kAvatarCardAspectRatio = 0.82;
