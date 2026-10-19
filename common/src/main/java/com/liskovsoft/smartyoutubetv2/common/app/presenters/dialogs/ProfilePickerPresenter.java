package com.liskovsoft.smartyoutubetv2.common.app.presenters.dialogs;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.text.TextUtils;

import com.liskovsoft.mediaserviceinterfaces.SignInService;
import com.liskovsoft.mediaserviceinterfaces.oauth.Account;
import com.liskovsoft.sharedutils.helpers.Helpers;
import com.liskovsoft.sharedutils.mylogger.Log;
import com.liskovsoft.smartyoutubetv2.common.R;
import com.liskovsoft.smartyoutubetv2.common.app.models.playback.ui.OptionItem;
import com.liskovsoft.smartyoutubetv2.common.app.models.playback.ui.UiOptionItem;
import com.liskovsoft.smartyoutubetv2.common.app.presenters.AppDialogPresenter;
import com.liskovsoft.smartyoutubetv2.common.app.presenters.PlaybackPresenter;
import com.liskovsoft.smartyoutubetv2.common.app.presenters.base.BasePresenter;
import com.liskovsoft.smartyoutubetv2.common.prefs.AccountsData;
import com.liskovsoft.smartyoutubetv2.common.utils.GlideIconFetcher;
import com.liskovsoft.smartyoutubetv2.common.utils.Utils;
import com.liskovsoft.youtubeapi.service.YouTubeServiceManager;

import java.util.ArrayList;
import java.util.List;

/**
 * Family build: one-press "Who's watching?" picker.<br/>
 * Lists YouTube Kids (when the official Kids app is installed), every signed-in account and the guest mode.<br/>
 * Picking an account switches to it, picking Kids hands over to the official YouTube Kids app.<br/>
 * Kept in its own file so upstream merges only touch the two call sites (NavigateTitleView, SplashPresenter).
 */
public class ProfilePickerPresenter extends BasePresenter<Void> {
    private static final String TAG = ProfilePickerPresenter.class.getSimpleName();
    /** Android TV / Google TV build first, then the phone/tablet build (cars, tablets). */
    private static final String[] KIDS_PACKAGES = {
            "com.google.android.youtube.tvkids",
            "com.google.android.apps.youtube.kids"
    };
    @SuppressLint("StaticFieldLeak")
    private static ProfilePickerPresenter sInstance;
    private final SignInService mSignInService;

    private ProfilePickerPresenter(Context context) {
        super(context);
        mSignInService = YouTubeServiceManager.instance().getSignInService();
    }

    public static ProfilePickerPresenter instance(Context context) {
        if (sInstance == null) {
            sInstance = new ProfilePickerPresenter(context);
        }

        sInstance.setContext(context);

        return sInstance;
    }

    /**
     * Startup entry. Respects the "Select account on boot" setting.
     */
    public void showOnBoot() {
        if (!AccountsData.instance(getContext()).isSelectAccountOnBootEnabled()) {
            return;
        }

        show(false);
    }

    /**
     * Top bar account button entry. Always shows the picker.
     */
    public void show() {
        show(true);
    }

    private void show(boolean force) {
        List<Account> accounts = mSignInService.getAccounts();

        // Nothing to choose from: one account (or none) and no Kids app
        if (!force && (accounts == null || accounts.size() <= 1) && getKidsIntent() == null) {
            return;
        }

        GlideIconFetcher.fetchDrawables(getContext(),
                accounts != null ? Helpers.map(accounts, Account::getAvatarImageUrl) : null,
                icons -> createAndShowDialog(accounts, icons));
    }

    private void unhold() {
        sInstance = null;
    }

    private void createAndShowDialog(List<Account> accounts, List<Drawable> icons) {
        if (getContext() == null) {
            return;
        }

        AppDialogPresenter dialogPresenter = AppDialogPresenter.instance(getContext());
        List<OptionItem> optionItems = new ArrayList<>();

        Intent kidsIntent = getKidsIntent();

        if (kidsIntent != null) {
            optionItems.add(UiOptionItem.from(
                    TextUtils.concat(Utils.icon(getKidsIcon()), " ", getContext().getString(R.string.profile_picker_kids)), option -> {
                        dialogPresenter.closeDialog();
                        openKids(kidsIntent);
                    }, false
            ));
        }

        if (accounts != null) {
            int index = -1;

            for (Account account : accounts) {
                index++;
                Drawable avatar = icons != null && accounts.size() == icons.size() ? icons.get(index) : null;
                optionItems.add(UiOptionItem.from(
                        TextUtils.concat(Utils.icon(avatar), " ", formatAccount(account)), option -> {
                            AccountSelectionPresenter.instance(getContext()).selectAccount(account);
                            dialogPresenter.closeDialog();
                        }, account.isSelected()
                ));
            }
        }

        optionItems.add(UiOptionItem.from(
                getContext().getString(R.string.dialog_account_none), option -> {
                    AccountSelectionPresenter.instance(getContext()).selectAccount(null);
                    dialogPresenter.closeDialog();
                }, mSignInService.getSelectedAccount() == null
        ));

        dialogPresenter.appendRadioCategory(getContext().getString(R.string.profile_picker_title), optionItems);
        dialogPresenter.showDialog(getContext().getString(R.string.profile_picker_title), this::unhold);
    }

    private void openKids(Intent kidsIntent) {
        // Don't let a background video keep playing over YouTube Kids
        PlaybackPresenter.instance(getContext()).forceFinish();

        try {
            getContext().startActivity(kidsIntent);
        } catch (Exception e) {
            Log.e(TAG, "Can't open YouTube Kids: %s", e.getMessage());
        }
    }

    private Intent getKidsIntent() {
        if (getContext() == null) {
            return null;
        }

        PackageManager pm = getContext().getPackageManager();

        for (String pkg : KIDS_PACKAGES) {
            Intent intent = null;

            if (Build.VERSION.SDK_INT >= 21) {
                intent = pm.getLeanbackLaunchIntentForPackage(pkg);
            }

            if (intent == null) {
                intent = pm.getLaunchIntentForPackage(pkg);
            }

            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                return intent;
            }
        }

        return null;
    }

    private Drawable getKidsIcon() {
        PackageManager pm = getContext().getPackageManager();

        for (String pkg : KIDS_PACKAGES) {
            try {
                return pm.getApplicationIcon(pkg);
            } catch (PackageManager.NameNotFoundException e) {
                // try next
            }
        }

        return null;
    }

    private static String formatAccount(Account account) {
        return account.getName() != null ? account.getName() : account.getEmail();
    }
}
