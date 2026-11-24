package com.cometchat.sampleapp.flutter.android;

import android.app.Instrumentation;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

/**
 * Patrol host test for the offline E2E suite in {@code patrol_test/}
 * (ENG-41597). {@code patrol test} generates one JUnit method per Dart test
 * next to this class and runs only those.
 *
 * Under any other runner (the plain AndroidJUnitRunner that
 * {@link MainActivityTest} uses) this class lists no tests, so a non-Patrol
 * androidTest run is unchanged.
 */
@RunWith(Parameterized.class)
public class PatrolMainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        Instrumentation registered = InstrumentationRegistry.getInstrumentation();
        if (!(registered instanceof PatrolJUnitRunner)) {
            return new Object[0];
        }
        PatrolJUnitRunner instrumentation = (PatrolJUnitRunner) registered;
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public PatrolMainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
