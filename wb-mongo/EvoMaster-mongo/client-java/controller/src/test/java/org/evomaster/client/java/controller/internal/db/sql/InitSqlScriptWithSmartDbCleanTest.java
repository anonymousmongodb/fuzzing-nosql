package org.evomaster.client.java.controller.internal.db.sql;

import io.restassured.http.ContentType;
import org.evomaster.client.java.controller.DatabaseTestTemplate;
import org.evomaster.client.java.controller.InstrumentedSutStarter;
import org.evomaster.client.java.sql.QueryResult;
import org.junit.jupiter.api.Test;

import java.util.Arrays;

import static io.restassured.RestAssured.given;
import io.restassured.RestAssured;
import org.evomaster.client.java.controller.api.ControllerConstants;

import static org.junit.jupiter.api.Assertions.assertEquals;

public interface InitSqlScriptWithSmartDbCleanTest extends DatabaseTestTemplate {

    default String getInitSqlScript() {
        return String.join("\n", Arrays.asList("INSERT INTO Bar (id, valueColumn) VALUES (0, 0);", "INSERT INTO Foo (id, valueColumn, bar_id) VALUES (0, 0, 0);"));
    }

    @Test
    default void testAccessedFkClean() throws Exception {
        EMSqlScriptRunner.execCommand(getConnection(), "CREATE TABLE Bar(id INT Primary Key, valueColumn INT)", true);
        EMSqlScriptRunner.execCommand(getConnection(), "CREATE TABLE Foo(id INT Primary Key, valueColumn INT, bar_id INT, " +
                "CONSTRAINT fk FOREIGN KEY (bar_id) REFERENCES Bar(id) )", true);

        InstrumentedSutStarter starter = getInstrumentedSutStarter();

        try {
            String url = start(starter);
            url += ControllerConstants.BASE_PATH;

            RestAssured.given().accept(ContentType.JSON)
                    .get(url + ControllerConstants.INFO_SUT_PATH)
                    .then()
                    .statusCode(200);

            QueryResult res;

            startNewTest(url);

            // db with init data
            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Bar;", true);
            assertEquals(1, res.seeRows().size());
            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Foo;", true);
            assertEquals(1, res.seeRows().size());

            RestAssured.given().accept(ContentType.JSON)
                    .get(url + ControllerConstants.TEST_RESULTS)
                    .then()
                    .statusCode(200);

            startNewTest(url);

            // db with init data
            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Bar;", true);
            assertEquals(1, res.seeRows().size());
            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Foo;", true);
            assertEquals(1, res.seeRows().size());

            // table is accessed with INSERT
            EMSqlScriptRunner.execCommand(getConnection(), "INSERT INTO Bar (id, valueColumn) VALUES (1, 1);", true);
            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Foo;", true);
            assertEquals(1, res.seeRows().size());

            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Bar;", true);
            assertEquals(2, res.seeRows().size());

            RestAssured.given().accept(ContentType.JSON)
                    .get(url + ControllerConstants.TEST_RESULTS)
                    .then()
                    .statusCode(200);

            startNewTest(url);

            // db only contains init data
            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Foo;", true);
            assertEquals(1, res.seeRows().size());

            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Bar;", true);
            assertEquals(1, res.seeRows().size());


            // table is accessed with INSERT
            EMSqlScriptRunner.execCommand(getConnection(), "INSERT INTO Foo (id, valueColumn, bar_id) VALUES (1, 0, 0);", true);

            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Foo;", true);
            assertEquals(2, res.seeRows().size());

            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Bar;", true);
            assertEquals(1, res.seeRows().size());

            RestAssured.given().accept(ContentType.JSON)
                .get(url + ControllerConstants.TEST_RESULTS)
                .then()
                .statusCode(200);

            startNewTest(url);

            // db only contains init data
            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Foo;", true);
            assertEquals(1, res.seeRows().size());

            res = EMSqlScriptRunner.execCommand(getConnection(), "SELECT * FROM Bar;", true);
            assertEquals(1, res.seeRows().size());

        } finally {
            starter.stop();
        }
    }

}
