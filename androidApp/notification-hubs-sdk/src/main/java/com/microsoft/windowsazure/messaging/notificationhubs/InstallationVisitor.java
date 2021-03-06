package com.microsoft.windowsazure.messaging.notificationhubs;

/**
 * A contract for allowing updates to an {@link Installation}.
 */
public interface InstallationVisitor {
    /**
     * Modifies an {@link Installation} to add more information before being registered with a
     * backend.
     * @param subject The {@link Installation} that should be modified to include more detail.
     */
    void visitInstallation(Installation subject);
}
