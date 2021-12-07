package com.contoso.productnotifier.ui.main;

import androidx.lifecycle.Observer;
import androidx.lifecycle.ViewModelProvider;

import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import com.contoso.productnotifier.CosmosDB;
import com.contoso.productnotifier.R;
import com.contoso.productnotifier.Subscription;
import com.microsoft.windowsazure.messaging.notificationhubs.NotificationHub;

import java.util.List;

public class SetupFragment extends Fragment {

    private SetupViewModel mViewModel;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mViewModel = new ViewModelProvider(this).get(SetupViewModel.class);
        final String unknownText = getResources().getString(R.string.unknown_information);
        mViewModel.setUnknownText(unknownText);
    }

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        View root = inflater.inflate(R.layout.setup_fragment, container, false);

        final TextView deviceTokenValue = root.findViewById(R.id.device_token_value);
        mViewModel.getDeviceToken().observe(getViewLifecycleOwner(), deviceTokenValue::setText);

        final TextView installationIdValue = root.findViewById(R.id.installation_id_value);
        mViewModel.getInstallationId().observe(getViewLifecycleOwner(), installationIdValue::setText);

        final Switch isEnabled = root.findViewById(R.id.enabled_switch);
        mViewModel.getIsEnabled().observe(getViewLifecycleOwner(), isEnabled::setChecked);
        isEnabled.setOnCheckedChangeListener((buttonView, isChecked) -> mViewModel.setIsEnabled(isChecked));

        final Button subscribeButton = root.findViewById(R.id.add_subscription_button);
        subscribeButton.setOnClickListener(v -> {
            /* Create a new subscription */
            Subscription subscription = new Subscription();
            subscription.setDeviceToken(deviceTokenValue.getText().toString());
            subscription.setCategory("xbox-series-x");
            subscription.setAction("shipped");

            /* Add the subscription to the Cosmos DB */
            CosmosDB db = new CosmosDB();
            String resourceLink = "dbs/users/colls/subscriptions/docs";
            String resourceId = "dbs/users/colls/subscriptions";
            //String dbResponse = db.getData("GET", "docs", resourceLink, resourceId);
            String dbResponse = db.addSubscription("POST", "docs", resourceLink, resourceId, subscription);

            Toast toast = Toast.makeText(getContext(), dbResponse, Toast.LENGTH_SHORT);
            toast.show();
        });


        final EditText tagToAddField = root.findViewById(R.id.add_tag_field);
        final Button tagToAddButton = root.findViewById(R.id.add_tag_button);
        tagToAddButton.setOnClickListener(v -> {
            try {
                mViewModel.addTag(tagToAddField.getText().toString());
            } catch (IllegalArgumentException e) {
                Toast toast = Toast.makeText(getContext(), R.string.invalid_tag_message, Toast.LENGTH_SHORT);
                toast.show();
            }
            tagToAddField.getText().clear();
        });

        final TagDisplayAdapter tagDisplayAdapter = new TagDisplayAdapter(mViewModel);
        final Observer<List<String>> tagsObserver = s -> tagDisplayAdapter.setTags(s);
        mViewModel.getTags().observe(getViewLifecycleOwner(), tagsObserver);
        final RecyclerView tagList = root.findViewById(R.id.tag_list);
        tagList.setLayoutManager(new LinearLayoutManager(getActivity()));
        tagList.setAdapter(tagDisplayAdapter);


        NotificationHub.setInstallationSavedListener(i -> {
            Toast.makeText(this.getContext(), getString(R.string.installation_saved_message), Toast.LENGTH_SHORT).show();
            mViewModel.setInstallationId(NotificationHub.getInstallationId());
            mViewModel.setDeviceToken(NotificationHub.getPushChannel());
        });
        NotificationHub.setInstallationSaveFailureListener(e -> Toast.makeText(this.getContext(), getString(R.string.installation_save_failure_message), Toast.LENGTH_SHORT).show());

        return root;
    }
}
