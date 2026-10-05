import com.android.recovery.tools.ImageGenerator;
import java.nio.file.Path;

// Use the in-tree generator API with a small font suitable for the 384px panel.
public class GenerateRecoveryText {
    public static void main(String[] args) throws Exception {
        String[] names = args.length > 3 && args[3].equals("full")
                ? new String[]{"installing", "installing_security", "erasing", "error", "no_command", "cancel_wipe_data", "factory_data_reset", "try_again", "wipe_data_confirmation", "wipe_data_menu_header"}
                : new String[]{"installing", "installing_security", "erasing", "error", "no_command"};
        for (String name : names) {
            ImageGenerator generator = new ImageGenerator(374, "recovery_" + name, 18f, args[0], true);
            generator.generateImage(generator.readLocalizedStringFromXmls(args[1], null),
                    Path.of(args[2], name + "_text.png").toString());
        }
    }
}
