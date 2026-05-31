package __PackageName__

import kotlin.test.Test
import kotlin.test.assertEquals

class GreeterTest {
    @Test
    fun `greet returns greeting with name`() {
        assertEquals("Hello, World!", greet("World"))
    }
}
