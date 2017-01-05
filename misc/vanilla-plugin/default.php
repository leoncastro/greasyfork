<?php if (!defined('APPLICATION')) exit();

// Define the plugin:
$PluginInfo['GreasyFork'] = array(
	'Name' => 'GreasyFork',
	'Description' => 'Greasy Fork customizations',
	'Version' => '1.0',
	'Author' => "Jason Barnabe",
	'RequiredApplications' => array('Vanilla' => '2.1'),
	'AuthorEmail' => 'jason.barnabe@gmail.com',
	'AuthorUrl' => 'https://greasyfork.org',
	'MobileFriendly' => TRUE
);

class GreasyForkPlugin extends Gdn_Plugin {

	# Link to main profile
	public function UserInfoModule_OnBasicInfo_Handler($Sender) {
		$UserModel = new UserModel();

		$UserModel->SQL
			->Select('u.ForeignUserKey', '', 'MainUserID')
			->From('UserAuthentication u')
			->Where('u.UserID', $Sender->User->UserID);

		$Row = $UserModel->SQL->Get()->FirstRow();
		echo '<dt><a href="/users/'.$Row->MainUserID.'">'.T('Greasy Fork Profile').'</a></dt><dd></dd>';
	}

	# Add CSS, JS, and link to main site
	public function Base_Render_Before($Sender) {
		$Sender->addCssFile('https://fonts.googleapis.com/css?family=Open+Sans');
	}

	# Going to render our own category selector
	public function PostController_BeforeFormInputs_Handler($Sender) {
		$Sender->ShowCategorySelector = false;
	}

	# Our own category selector, with description
	public function PostController_BeforeBodyInput_Handler($Sender) {
		# If the script ID is passed in, it will be hardcoded to category 4.
		if ($this->ScriptIDPassed($Sender)) {
			return;
		}
		echo '<div class="P">';
		echo '<div class="Category">';
		echo $Sender->Form->Label('Category', 'CategoryID'), ' ';
		echo '<br>';
		$SelectedCategory = GetValue('CategoryID', $Sender->Category);
		foreach (CategoryModel::Categories() as $c) {
			# -1 is the root
			if ($c['CategoryID'] != -1) {
				#4 is Style Reviews, which should only by used when script id is passed (and skips this anyway) or by mods
				if ($c['CategoryID'] != 4 || Gdn::Session()->CheckPermission('Vanilla.Discussions.Edit')) {
					echo '<input name="CategoryID" id="category-'.$c['CategoryID'].'" type="radio" value="'.$c['CategoryID'].'"'.($SelectedCategory == $c['CategoryID'] ? ' checked' : '').'><label for="category-'.$c['CategoryID'].'">'.$c['Name'].' - '.$c['Description'].'</label><br>';
				}
			}
		}
		#echo $Sender->Form->CategoryDropDown('CategoryID', array('Value' => GetValue('CategoryID', $this->Category)));
		echo '</div>';
		echo '</div>';
	}

	private function ScriptIDPassed($Sender) {
		# Same logic as GetItemID in DiscussionAbout
		if (isset($Sender->Discussion) && is_numeric($Sender->Discussion->ScriptID)) {
			return $Sender->Discussion->ScriptID != '0';
		}
		if (isset($_REQUEST['script']) && is_numeric($_REQUEST['script'])) {
			return $_REQUEST['script'] != '0';
		}
		return false;
	}

	public function PostController_AfterDiscussionSave_Handler(&$Sender){
		$this->SendNotification($Sender, true);
	}

	public function PostController_AfterCommentSave_Handler(&$Sender){
		$this->SendNotification($Sender, false);
	}

	private function SendNotification($Sender, $IsDiscussion) {
		$Session = Gdn::Session();

		# don't send on edit
		if ($Sender->RequestMethod == 'editdiscussion' || $Sender->RequestMethod == 'editcomment') {
			return;
		}

		# discussion info
		$UserName = $Session->User->Name;
		$DiscussionID = $Sender->EventArguments['Discussion']->DiscussionID;
		$DiscussionName = $Sender->EventArguments['Discussion']->Name;
		$ScriptID = $Sender->EventArguments['Discussion']->ScriptID;

		# no script - do nothing
		if (!isset($ScriptID) || !is_numeric($ScriptID)) {
			return;
		}

		# look up the user we might e-mail
		$DiscussionModel = new DiscussionModel();
		$prefix = $DiscussionModel->SQL->Database->DatabasePrefix;
		$DiscussionModel->SQL->Database->DatabasePrefix = '';
		$UserInfo = $DiscussionModel->SQL->Select('u.author_email_notification_type_id, u.email, u.name, s.default_name script_name, u.id, ua.UserID forum_user_id')
			->From('scripts s')
			->Join('users u', 's.user_id = u.id')
			->Join('GDN_UserAuthentication ua', 'ua.ForeignUserKey = u.id')
			->Where('s.id', $ScriptID)
			->Get()->NextRow(DATASET_TYPE_ARRAY);
		$DiscussionModel->SQL->Database->DatabasePrefix = $prefix;

		$NotificationPreference = $UserInfo['author_email_notification_type_id'];

		# 1: no notifications
		# 2: new discussions
		# 3: new discussions and comments

		# no notifications
		if ($NotificationPreference != 2 && $NotificationPreference != 3) {
			return;
		}

		# discussions only
		if ($NotificationPreference == 2 && !$IsDiscussion) {
			return;
		}

		# don't self-notify
		if ($UserInfo['forum_user_id'] == $Session->User->UserID) {
			return;
		}

		$NotificationEmail = $UserInfo['email'];
		$NotificationName = $UserInfo['name'];
		$ScriptName = $UserInfo['script_name'];
		$ActivityHeadline = $DiscussionName.' - '.$ScriptName;
		$UserId = $UserInfo['id'];
		$AccountUrl = 'https://greasyfork.org/users/'.$UserId;

		$Email = new Gdn_Email();
		if ($IsDiscussion) {
			$Email->Subject(sprintf(T('[%1$s] %2$s'), Gdn::Config('Garden.Title'), $ActivityHeadline));
		} else {
			$Email->Subject(sprintf(T('Re: [%1$s] %2$s'), Gdn::Config('Garden.Title'), $ActivityHeadline));
		}
		$Email->To($NotificationEmail, $NotificationName);
		if ($IsDiscussion) {
			$Email->Message(sprintf("%s started a discussion '%s' on your script '%s'. Check it out: %s\n\nYou can change your notification settings on your Greasy Fork account page at %s", $UserName, $DiscussionName, $ScriptName, Url('/discussion/'.$DiscussionID.'/'.Gdn_Format::Url($DiscussionName), TRUE), $AccountUrl));
		} else {
			$Email->Message(sprintf("%s commented on the discussion '%s' on your script '%s'. Check it out: %s\n\nYou can change your notification settings on your Greasy Fork account page at %s", $UserName, $DiscussionName, $ScriptName, Url('/discussion/'.$DiscussionID.'/'.Gdn_Format::Url($DiscussionName), TRUE), $AccountUrl));
		}

		# For development
		#print_r($Email);
		#die;

		try {
			$Email->Send();
		} catch (Exception $ex) {
			# report but keep going
			echo $ex;
		}

	}

}
