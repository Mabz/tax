# EasyTax Admin Quick Reference Guide

## Getting Started

### Prerequisites
- You must have **Superuser** role to access admin features
- Admin features are only visible to authenticated superusers

### Accessing Admin Features
1. **Admin Panel Icon**: Click the admin panel settings icon in the top-right of the home screen
2. **Admin Functions Card**: Use the red admin functions card on the home screen
3. **Direct Buttons**: Click "Manage Countries" or "Manage Users" buttons

---

## Country Management

### Adding a New Country
1. Navigate to Country Management
2. Click the **+** (Add) floating action button
3. Fill in the form:
   - **Country Name**: Full country name (e.g., "South Africa")
   - **Country Code**: 3-letter ISO code (e.g., "ZAF")
   - **Revenue Service**: Name of the tax authority
   - **Active**: Toggle to enable/disable the country
4. Click **Add** to save

### Editing a Country
1. Find the country in the list
2. Click the **Edit** (pencil) icon
3. Modify the fields as needed
4. Click **Update** to save changes

### Activating/Deactivating Countries
- **Quick Toggle**: Click the toggle icon next to each country
- **Form Toggle**: Use the Active switch when adding/editing

### Deleting a Country
1. Click the **Delete** (trash) icon next to the country
2. Confirm the deletion in the dialog
3. **Warning**: This action cannot be undone!

---

## User Management

### Searching for Users

#### Search by Exact Email
1. Enter the complete email address in the search field
2. Click **Search by Email**
3. Results will show the exact match (if found)

#### Search by Name or Email Pattern
1. Enter part of a name or email in the search field
2. Click **Search All**
3. Results will show all matching users

#### Show All Users
- Click **Show All** to display all users in the system
- Use **Clear** (X) button to reset search

### Editing User Profiles
1. Find the user in the search results
2. Click the **Edit** (pencil) icon
3. Modify:
   - **Full Name**: User's display name
   - **Email**: User's email address
4. Click **Update** to save

### Deleting Users
1. Click the **Delete** (trash) icon next to the user
2. Confirm the deletion in the dialog
3. **Warning**: This will permanently remove the user!

---

## Tips and Best Practices

### Country Management
- **Always activate countries** that should be operational
- **Use proper ISO codes** for country codes (3 letters, uppercase)
- **Test country status** before making countries live
- **Keep revenue service names accurate** for official correspondence

### User Management
- **Search by email first** for exact matches (faster)
- **Use pattern search** when you're not sure of the exact email
- **Be careful with deletions** - they cannot be undone
- **Update user information** to keep profiles current

### General Admin Tips
- **Refresh data** by pulling down on lists
- **Check loading indicators** to know when operations are complete
- **Read error messages** carefully if something goes wrong
- **Use confirmation dialogs** to prevent accidental changes

---

## Troubleshooting

### Common Issues

#### "Access Denied" Error
- **Cause**: You don't have superuser permissions
- **Solution**: Contact a system administrator to assign superuser role

#### Country Code Validation Error
- **Cause**: Invalid country code format
- **Solution**: Use exactly 3 uppercase letters (ISO 3166-1 alpha-3)

#### User Not Found
- **Cause**: Email doesn't exist in the system
- **Solution**: Check spelling or try pattern search

#### Operation Failed
- **Cause**: Network or database error
- **Solution**: Try again, check internet connection

### Getting Help
- Check error messages in red snackbars at the bottom of the screen
- Try refreshing the data by pulling down on lists
- Restart the app if persistent issues occur
- Contact technical support for database-related issues

---

## Security Notes

- **Admin access is logged** - all actions are tracked
- **Only superusers** can access these features
- **Deletions are permanent** - there is no undo
- **Changes affect all users** - be careful with country status changes
- **Email changes** may affect user login ability

---

## Quick Actions Summary

| Action | Location | Icon | Shortcut |
|--------|----------|------|----------|
| Add Country | Country Management | + (FAB) | - |
| Edit Country | Country List | ✏️ | - |
| Toggle Country | Country List | 🔘 | - |
| Delete Country | Country List | 🗑️ | - |
| Search User by Email | User Management | 📧 Button | - |
| Search Users | User Management | 🔍 Button | - |
| Edit User | User List | ✏️ | - |
| Delete User | User List | 🗑️ | - |
| Admin Panel | Home Screen | ⚙️ (Top Bar) | - |
| Refresh Data | Any List | Pull Down | - |

Remember: With great power comes great responsibility! Always double-check before making changes that affect other users.
